local M = {}

---@class CreateTableConfig options of table creation
---@field prompt? string Prompt to show in table size input
---@field default_n_lines? integer Default amount of lines to use, if no amount is specified in the input
---@field max_width? integer Cap on the amount of columns to use
---@field max_height? integer Prompt to show in table size input

---@class MarkdownTablePluginConfig
---@field new_table? CreateTableConfig

---@type MarkdownTablePluginConfig
M.defaults = {
	new_table = {
		prompt = "Enter table size",
		default_n_lines = 0,
		max_width = 30,
		max_height = 50,
	},
}

M.options = M.defaults

---Initialization of instance configuration options.
---@param opts? MarkdownTablePluginConfig
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
