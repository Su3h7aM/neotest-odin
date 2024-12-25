local lib = require("neotest.lib")

local odin = {}

odin.adapter = {
	name = "neotest-odin",
	version = "v0.1.0",
}

odin._test_query = [[
    ;; query package
    (package_declaration
        (identifier) @package.name ) @package.definition
    
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

---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function odin.adapter.discover_positions(file_path)
	--TODO: stop using the builtin parse_positions(), build a custom for generate a real tree
	local positions = lib.treesitter.parse_positions(file_path, odin._test_query, {})

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
			command = "odin test " .. head_path .. " -define:ODIN_TEST_NAMES=main." .. position.name .. flags,
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

	local status = "failed"
	if result.code == 0 then
		status = "passed"
	end

	--TODO: parse result.output for generate a short version and errors messages
	local results = {
		[spec.context.id] = {
			status = status,
			output = result.output,
			--          short = "testando: ola",
			-- errors = {
			-- 	{ message = "erro", line = 5 },
			-- },
		},
	}

	return results
end

return odin.adapter
