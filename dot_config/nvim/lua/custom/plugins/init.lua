-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

---@module "lazy"
---@type LazySpec
return {
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		opts = {},
	},
	{
		"saghen/blink.cmp",
		dependencies = {
			{
				"rafamadriz/friendly-snippets",
				config = function()
					require("luasnip.loaders.from_vscode").lazy_load()
				end,
			},
		},
	},
	{
		"lewis6991/gitsigns.nvim",
		opts = {
			on_attach = function(bufnr)
				local gs = require("gitsigns")
				local function map(mode, lhs, rhs, desc)
					vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
				end
				map("n", "]c", function()
					if vim.wo.diff then vim.cmd.normal({ "]c", bang = true }) else gs.nav_hunk("next") end
				end, "Next Git hunk")
				map("n", "[c", function()
					if vim.wo.diff then vim.cmd.normal({ "[c", bang = true }) else gs.nav_hunk("prev") end
				end, "Previous Git hunk")
				map({ "n", "v" }, "<leader>hs", gs.stage_hunk, "Git stage hunk")
				map({ "n", "v" }, "<leader>hr", gs.reset_hunk, "Git reset hunk")
				map("n", "<leader>hu", gs.undo_stage_hunk, "Git undo staged hunk")
				map("n", "<leader>hp", gs.preview_hunk, "Git preview hunk")
				map("n", "<leader>hb", gs.blame_line, "Git blame line")
				map("n", "<leader>hd", gs.diffthis, "Git diff index")
			end,
		},
	},
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"nvim-neotest/nvim-nio",
		},
		keys = {
			{ "<F5>", function() require("dap").continue() end, desc = "Debug: start/continue" },
			{ "<F1>", function() require("dap").step_into() end, desc = "Debug: step into" },
			{ "<F2>", function() require("dap").step_over() end, desc = "Debug: step over" },
			{ "<F3>", function() require("dap").step_out() end, desc = "Debug: step out" },
			{ "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Debug breakpoint" },
			{ "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end, desc = "Debug conditional breakpoint" },
			{ "<leader>du", function() require("dapui").toggle() end, desc = "Debug UI" },
			{ "<leader>dr", function() require("dap").repl.open() end, desc = "Debug REPL" },
			{ "<leader>dx", function() require("dap").terminate() end, desc = "Debug terminate" },
		},
		config = function()
			local dap, dapui = require("dap"), require("dapui")
			dap.adapters.gdb = {
				type = "executable",
				command = "gdb",
				args = { "--quiet", "--interpreter=dap" },
			}
			local cpp = require("custom.cpp")
			dap.configurations.cpp = {
				{
					name = "Launch executable",
					type = "gdb",
					request = "launch",
					program = cpp.debug_program,
					cwd = function() return cpp.root() end,
					stopAtBeginningOfMainSubprogram = false,
				},
				{
					name = "Attach to process",
					type = "gdb",
					request = "attach",
					pid = require("dap.utils").pick_process,
					cwd = function() return cpp.root() end,
				},
			}
			dap.configurations.c = dap.configurations.cpp
			dapui.setup()
			dap.listeners.after.event_initialized["cpp_dapui"] = dapui.open
			dap.listeners.before.event_terminated["cpp_dapui"] = dapui.close
			dap.listeners.before.event_exited["cpp_dapui"] = dapui.close
		end,
	},
}
