local M = {}

local markers = { "CMakePresets.json", "CMakeLists.txt", "compile_commands.json", "Makefile", ".git" }

function M.root()
	local start = vim.api.nvim_buf_get_name(0)
	if start == "" then start = vim.uv.cwd() end
	local stat = vim.uv.fs_stat(start)
	if stat and stat.type == "file" then start = vim.fs.dirname(start) end
	local found = vim.fs.find(markers, { upward = true, path = start })[1]
	return found and vim.fs.dirname(found) or vim.uv.cwd()
end

local function build_dir()
	return M.root() .. "/build"
end

local function project_has(name)
	return vim.uv.fs_stat(M.root() .. "/" .. name) ~= nil
end

local errorformat = table.concat({
	"%f:%l:%c: %trror: %m",
	"%f:%l:%c: %tarning: %m",
	"%f:%l:%c: %m",
	"%f:%l: %trror: %m",
	"%f:%l: %tarning: %m",
	"%f:%l: %m",
	"%-G%.%#",
}, ",")

local function run(name, cmd, opts)
	opts = opts or {}
	vim.notify(name .. " started", vim.log.levels.INFO)
	vim.system(cmd, { cwd = opts.cwd or M.root(), text = true }, function(result)
		vim.schedule(function()
			local output = (result.stdout or "") .. (result.stderr or "")
			vim.fn.setqflist({}, " ", {
				title = name,
				lines = vim.split(output, "\n", { trimempty = true }),
				efm = opts.efm or errorformat,
			})
			if result.code == 0 then
				vim.notify(name .. " succeeded", vim.log.levels.INFO)
			else
				vim.notify(name .. " failed (exit " .. result.code .. ")", vim.log.levels.ERROR)
				vim.cmd.copen()
			end
		end)
	end)
end

function M.configure()
	if not project_has("CMakeLists.txt") then
		vim.notify("No CMakeLists.txt found in project root", vim.log.levels.WARN)
		return
	end
	run("CMake configure", { "cmake", "-S", M.root(), "-B", build_dir(), "-G", "Ninja", "-DCMAKE_BUILD_TYPE=Debug", "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" })
end

function M.build()
	if project_has("CMakeLists.txt") then
		run("CMake build", { "cmake", "--build", build_dir() })
	elseif project_has("Makefile") then
		run("Make build", { "make", "-j" .. tostring(vim.uv.available_parallelism()) })
	else
		vim.notify("No CMakeLists.txt or Makefile found", vim.log.levels.WARN)
	end
end

function M.clean()
	if project_has("CMakeLists.txt") then
		run("CMake clean", { "cmake", "--build", build_dir(), "--target", "clean" })
	elseif project_has("Makefile") then
		run("Make clean", { "make", "clean" })
	else
		vim.notify("No CMakeLists.txt or Makefile found", vim.log.levels.WARN)
	end
end

function M.test()
	if project_has("CMakeLists.txt") then
		run("CTest", { "ctest", "--test-dir", build_dir(), "--output-on-failure" }, { efm = "%f:%l: %m,%-G%.%#" })
	elseif project_has("Makefile") then
		run("Make test", { "make", "test" })
	else
		vim.notify("No CMakeLists.txt or Makefile found", vim.log.levels.WARN)
	end
end

function M.tidy()
	local file = vim.api.nvim_buf_get_name(0)
	if not vim.tbl_contains({ "c", "cpp" }, vim.bo.filetype) or file == "" then
		vim.notify("Clang-tidy requires a C or C++ file", vim.log.levels.WARN)
		return
	end
	run("Clang-tidy", { "clang-tidy", "-p", build_dir(), file })
end

local function executables()
	local files = vim.fn.glob(build_dir() .. "/**/*", false, true)
	return vim.tbl_filter(function(path)
		return vim.fn.isdirectory(path) == 0
			and vim.fn.executable(path) == 1
			and not path:find("/CMakeFiles/")
	end, files)
end

function M.debug_program()
	local choices = executables()
	local default = choices[1] or (build_dir() .. "/")
	return vim.fn.input("Executable: ", default, "file")
end

local function switch_header()
	if vim.fn.exists(":LspClangdSwitchSourceHeader") == 2 then
		vim.cmd.LspClangdSwitchSourceHeader()
	else
		vim.notify("clangd is not attached", vim.log.levels.WARN)
	end
end

function M.setup()
	vim.api.nvim_create_user_command("CMakeConfigure", M.configure, {})
	vim.api.nvim_create_user_command("CMakeBuild", M.build, {})
	vim.api.nvim_create_user_command("CMakeClean", M.clean, {})
	vim.api.nvim_create_user_command("CTest", M.test, {})
	vim.api.nvim_create_user_command("ClangTidy", M.tidy, {})

	vim.keymap.set("n", "<leader>cc", M.configure, { desc = "CMake configure" })
	vim.keymap.set("n", "<leader>cb", M.build, { desc = "CMake build" })
	vim.keymap.set("n", "<leader>cx", M.clean, { desc = "CMake clean" })
	vim.keymap.set("n", "<leader>ct", M.test, { desc = "CTest" })
	vim.keymap.set("n", "<leader>ca", M.tidy, { desc = "Clang-tidy current file" })
	vim.keymap.set("n", "<leader>ch", switch_header, { desc = "C/C++ switch source/header" })

	local warned = {}
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("cpp-compilation-database", { clear = true }),
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if not client or client.name ~= "clangd" then return end
			local root = client.root_dir or M.root()
			local candidates = { root .. "/compile_commands.json", root .. "/build/compile_commands.json" }
			if not warned[root] and not vim.iter(candidates):any(function(path) return vim.uv.fs_stat(path) ~= nil end) then
				warned[root] = true
				vim.notify("clangd: no compile_commands.json found; run :CMakeConfigure", vim.log.levels.WARN)
			end
		end,
	})
end

return M
