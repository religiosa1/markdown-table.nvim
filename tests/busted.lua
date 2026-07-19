#!/usr/bin/env -S nvim -l
vim.env.LAZY_STDPATH = ".tests"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

-- lazy.minit adds the cwd as a plugin, so `require("markdown-table.*")` resolves.
-- treesitter is only needed for edit-table's table-finding, not the pure parser specs.
require("lazy.minit").busted({
	spec = {
		"nvim-treesitter/nvim-treesitter",
	},
	-- Locally, hererocks compiles an isolated Lua 5.1 for the busted rock. In CI
	-- that async build gets killed when `nvim -l` exits mid-compile, leaving a
	-- corrupt hererocks ("version 5.1 not installed"). There we use the system
	-- luarocks instead (installed by the workflow).
	rocks = { hererocks = vim.env.CI == nil },
})
