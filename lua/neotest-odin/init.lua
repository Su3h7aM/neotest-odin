local lib = require("neotest.lib")

local odin = {}

odin.adapter = {
	name = "neotest-odin",
	version = "v0.1.1",
}

odin._test_query = [[
    ;; query for test procedures
    (procedure_declaration
        (attributes
            (attribute
                (identifier) @attribute (#eq? @attribute "test")))
        (identifier) @test.name ) @test.definition
]]

---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function odin.adapter.root(dir)
	return dir
end

---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function odin.adapter.filter_dir(name, rel_path, root)
	local ignore_dirs = { ".git", "node_modules", ".venv", "venv", "build", "bin" }

	for _, ignore in ipairs(ignore_dirs) do
		if name == ignore then
			return false
		end
	end

	return true
end

---@async
---@param file_path string
---@return boolean
function odin.adapter.is_test_file(file_path)
	local is_odin = vim.endswith(file_path, ".odin")
	local is_test = false

	if is_odin then
		local content = lib.files.read(file_path)
		local tree = lib.treesitter.parse_positions_from_string(file_path, content, odin._test_query, {})

		is_test = #tree:to_list() > 1
	end

	return is_test
end

odin._get_match_type = function(captured_nodes)
	if captured_nodes["test.name"] then
		return "test"
	end
end

odin._build_position = function(file_path, source, captured_nodes)
	local match_type = odin._get_match_type(captured_nodes)
	if match_type then
		---@type string
		local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
		local definition = captured_nodes[match_type .. ".definition"]

		local pkg = ""
		if match_type == "test" then
			pkg = source:match("^%s*package%s+(%w+)")
		end

		return {
			type = match_type,
			path = file_path,
			name = name,
			range = { definition:range() },
			pkg = pkg,
		}
	end
end

odin._position_id = function(position)
	if position.type == "test" then
		return position.path .. "::" .. position.pkg .. "::" .. position.name
	end

	return position.path
end

---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function odin.adapter.discover_positions(file_path)
	--TODO: stop using the builtin parse_positions(), build a custom for generate a real tree
	local positions = lib.treesitter.parse_positions(file_path, odin._test_query, {
		require_namespaces = false,
		nested_tests = false,
		build_position = odin._build_position,
		position_id = odin._position_id,
	})

	return positions
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function odin.adapter.build_spec(args)
	local position = args.tree:data()
	local head_path = vim.fn.fnamemodify(position.path, ":h")

	local flags = ""
	--local flags = " -define:ODIN_TEST_LOG_LEVEL=warning -define:ODIN_TEST_TRACK_MEMORY=false -define:ODIN_TEST_FANCY=false"

	local specs = {}

	if position.type == "test" then
		table.insert(specs, {
			command = "odin test "
				.. head_path
				.. " -define:ODIN_TEST_NAMES="
				.. position.pkg
				.. "."
				.. position.name
				.. flags
				.. " > /dev/null",
			context = {
				name = position.name,
				id = position.id,
			},
		})
	elseif position.type == "file" then
		return nil
		-- list = args.tree:to_list()
		--
		-- for _, item in ipairs(list) do
		-- 	if #item == 0 then
		-- 		goto continue
		-- 	end
		--
		-- 	if item[1].type == "test" then
		-- 		table.insert(specs, {
		-- 			command = "odin test " .. head_path .. " -define:ODIN_TEST_NAMES=main." .. item[1].name,
		-- 			context = {
		-- 				name = item[1].name,
		-- 				id = item[1].id,
		-- 			},
		-- 		})
		-- 	end
		--
		-- 	::continue::
		-- end
	elseif position.type == "dir" then
		return nil
		-- table.insert(specs, {
		-- 	command = "odin test " .. position.path .. flags,
		-- 	context = {
		-- 		name = position.name,
		-- 		id = position.id,
		-- 	},
		-- })
	end

	return specs
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function odin.adapter.results(spec, result, tree)
	-- local output = assert(io.open(result.output))
	-- local line = output:read("*a")
	-- output:close()

	local sucess, file = pcall(lib.files.read_lines, result.output)

	if not sucess then
		lib.notify("Error reading file: " .. result.output)
	end

	local n_errors = 1
	local errors = {}
	local short = ""
	for _, line in ipairs(file) do
		local is_error = line:match("%[ERROR%]")
		local is_finished = line:match("Finished")

		if is_error then
			local file_name, err_line, proc, msg = line:match("%[(%w-[_%w]%w-%.odin):(%d-):(%w-[_%w]%w-)%(%)%]%s(.*)")

			errors[n_errors] = {
				message = msg,
				line = tonumber(err_line) - 1,
			}

			n_errors = n_errors + 1
		end

		if is_finished then
			short = line
		end
	end

	local status = "failed"
	if result.code == 0 then
		status = "passed"
	end

	--TODO: parse result.output for generate a short version and errors messages
	local results = {
		[spec.context.id] = {
			status = status,
			output = result.output,
			short = short,
			errors = errors,
		},
	}

	return results
end

return odin.adapter
