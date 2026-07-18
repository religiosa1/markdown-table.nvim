#!/usr/bin/env -S nvim -l
vim.env.LAZY_STDPATH = ".tests"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

-- lazy.minit adds the cwd as a plugin, so `require("markdown-table.*")` resolves.
-- treesitter is only needed for edit-table's table-finding, not the pure parser specs.
require("lazy.minit").busted({
	spec = {
		"nvim-treesitter/nvim-treesitter",
	},
})
