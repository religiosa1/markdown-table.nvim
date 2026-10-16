local M = {}

---@class CreateTableConfig options of table creation
---@field prompt? string Prompt to show in table size input
---@field default_n_lines? integer Default amount of lines to use, if no amount is specified in the input
---@field max_width? integer Cap on the amount of columns to use
---@field max_height? integer Prompt to show in table size input
---@field header? HeaderFormat Header text: format string (`%d` is the column index) or `fun(idx): string`

---@class YankInfo what yank_converted put into the register
---@field count integer number of yanked lines
---@field direction "to_tsv" | "to_markdown"
---@field skip_header boolean header row was dropped (TSV only)

---@class YankConfig
---@field message? fun(info: YankInfo): string? notification text after a yank; nil skips it

---@class PasteConfig
---@field missing_separator? MissingSeparatorMode pasted content without a header separator: first line is the "header", or it's all "body"

---@class MarkdownTablePluginConfig
---@field new_table? CreateTableConfig
---@field new_column? CreateColumnConfig
---@field paste? PasteConfig
---@field yank? YankConfig

---@type MarkdownTablePluginConfig
M.defaults = {
	new_table = {
		prompt = "Enter table size",
		default_n_lines = 0,
		max_width = 30,
		max_height = 50,
		header = "Header%d",
	},
	new_column = {
		header = "Header",
	},
	paste = {
		missing_separator = "header",
	},
	yank = {
		message = function(info)
			if info.direction == "to_markdown" then
				return string.format("Yanked %d markdown table lines", info.count)
			end
			local header = info.skip_header and "without" or "with"
			return string.format("Yanked %d TSV lines %s header", info.count, header)
		end,
	},
}

M.options = M.defaults

---Initialization of instance configuration options.
---@param opts? MarkdownTablePluginConfig
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
