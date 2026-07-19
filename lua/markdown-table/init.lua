local EditTable = require("markdown-table.edit-table")

local M = {}

function M.create_table()
	local opts = require("markdown-table.config").options
	local CreateTable = require("markdown-table.create-table")
	local input_str = vim.fn.input({
		prompt = opts.new_table.prompt,
	})
	if not input_str or input_str == "" then
		return
	end
	local x, y = CreateTable.tokenize_create_table_input(input_str)
	local lines = CreateTable.create_table_lines(x, y, opts.new_table)
	vim.api.nvim_put(lines, "l", true, false)
end

---@class PasteColumnArgs
---@field paste_mode? "before" | "after" paste the column before or after current column, default to after
---@field search_mode? SearchMode: where to search for closes table. If not provided, inferred from paste_mode
---@field from_reg? string -- TODO: register to paste from, nil to avoid pasting

---Paste or add column
---@param args? PasteColumnArgs
function M.paste_column(args)
	args = args or {}
	local is_paste_after = args.paste_mode ~= "before"
	local search_mode = args.search_mode or (is_paste_after and "forward" or "backward")

	local pos = vim.fn.getcurpos()

	local table_pos = EditTable.find_closest_markdown_table({
		pos = pos,
		search_mode = search_mode,
	})
	if table_pos == nil then
		vim.notify("No markdown table found")
		return
	end

	local column_idx = EditTable.is_cursor_inside_table(pos, table_pos)
			and EditTable.get_column_under_pos({
				table_pos = table_pos,
				cursor_pos = pos,
			})
		or (is_paste_after and math.huge or 0)

	if is_paste_after and column_idx ~= math.huge then
		column_idx = column_idx + 1
	end
	EditTable.add_column({
		table_pos = table_pos,
		column_idx = column_idx,
	})
end

---@class DeleteColumnArgs
---@field search_mode? SearchMode: where to search for closes table. If not provided, inferred from paste_mode
---@field to_reg? string | string[] | boolean register(s) to yank the removed columns into. A name, a list of names, or `true` to route by 'clipboard'. nil to skip

---Delete (optionally cut into a register) the column(s) under the cursor/selection
---@param args? DeleteColumnArgs
function M.delete_column(args)
	args = args or {}
	local cursors = EditTable.get_start_stop_cursors_pos()

	local table_pos = EditTable.find_closest_markdown_table({
		pos = cursors.current,
		search_mode = "exact",
	})
	if table_pos == nil then
		vim.notify("No markdown table found")
		return
	end
	local current_column = EditTable.get_column_under_pos({
		table_pos = table_pos,
		cursor_pos = cursors.current,
	})
	local end_column
	if cursors.other_end ~= nil then
		end_column = EditTable.get_column_under_pos({
			table_pos = table_pos,
			cursor_pos = cursors.other_end,
		})
	end
	local deleted = EditTable.delete_column({
		table_pos = table_pos,
		column_idx = current_column,
		to_column_idx = end_column or current_column,
	})
	if args.to_reg then
		require("markdown-table.registers").cols_to_reg(deleted, args.to_reg)
	end
end

---MarkdownTable plugin initializer
---@param opts? MarkdownTablePluginConfig
function M.setup(opts)
	require("markdown-table.config").setup(opts)
end

return M
