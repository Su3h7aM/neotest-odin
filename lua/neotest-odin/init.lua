local lib = require("neotest.lib")
local async = require("neotest.async")

local odin = {}

odin.adapter = {
	name = "neotest-odin",
	version = "v0.0.1",
}

odin._test_query = [[
    ;; query for test procedures
    ((procedure_declaration
        (attributes
            (attribute
                (identifier) @attribute (#eq? @attribute "test")))
        (identifier) @test.name )) @test.definition
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
	return false
end

---@async
---@param file_path string
---@return boolean
function odin.adapter.is_test_file(file_path)
	return vim.endswith(file_path, "_test.odin")
end

---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function odin.adapter.discover_positions(file_path)
	local positions = lib.treesitter.parse_positions(file_path, odin._test_query, {})

	return positions
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function odin.adapter.build_spec(args)
	local position = args.tree:data()
	local cwd = vim.fn.getcwd()
	local head_path = vim.fn.fnamemodify(position.path, ":h")

	local command = nil
	local flags =
		" -define:ODIN_TEST_LOG_LEVEL=warning -define:ODIN_TEST_TRACK_MEMORY=false -define:ODIN_TEST_FANCY=false"

	local results = async.fn.tempname()

	if position.type == "test" or position.type == "namespace" then
		command = "odin test " .. head_path .. " -define:ODIN_TEST_NAMES=main." .. position.name .. flags
	elseif position.type == "file" then
		command = "odin test " .. head_path .. flags
	elseif position.type == "dir" then
		command = "odin test " .. head_path .. flags
	end

	return {
		command = command .. " 2>" .. results,
		context = {
			results = results,
		},
		cwd = cwd,
	}
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function odin.adapter.results(spec, result, tree)
	local position = tree:data()
	local results = {}
	local file = assert(io.open(spec.context.results))
	local line = file:read("l")

	while line do
		local passed = string.match(line, "successful")
		if passed ~= nil then
			results[position.path .. "::" .. position.name] = { status = "passed" }
		end

		local failed = string.match(line, "failed")
		if failed ~= nil then
			results[position.path .. "::" .. position.name] = { status = "failed" }
		end

		line = file:read("l")
	end

	if file then
		file:close()
	end

	return results
end

return odin.adapter
