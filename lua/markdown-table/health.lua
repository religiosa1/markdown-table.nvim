local M = {}

function M.check()
	vim.health.start("markdown-table")

	if vim.fn.has("nvim-0.10.0") == 1 then
		vim.health.ok("Neovim version is compatible")
	else
		vim.health.error("Neovim 0.10.0+ is required", { "Upgrade Neovim" })
	end

	local ok, res = pcall(vim.treesitter.language.add, "markdown")
	if ok and res then
		vim.health.ok("markdown treesitter parser installed")
	else
		vim.health.error(
			"markdown treesitter parser missing",
			{ "Install it, e.g. `:TSInstall markdown` (nvim-treesitter)" }
		)
	end
end

return M
