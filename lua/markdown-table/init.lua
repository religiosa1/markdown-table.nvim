local EditTable = require("markdown-table.edit-table")

local M = {}

---Leave visual mode like native `y`/`d` do; `gv` reselects. Call after reading the selection.
local function exit_visual()
	if vim.fn.mode():match("^[vV\22]") then
		vim.cmd("normal! \27")
	end
end

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
---@field from_reg? string | string[] | boolean register to paste columns from. A name, list of names, or `true` to route by 'clipboard'. nil adds a blank column

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
	local columns
	if args.from_reg then
		columns = require("markdown-table.registers").cols_from_reg(args.from_reg)
	end
	EditTable.add_column({
		table_pos = table_pos,
		column_idx = column_idx,
		columns = columns,
		config = require("markdown-table.config").options.new_column,
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
	exit_visual()

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

---@class YankConvertedArgs: ConvertOpts
---@field to_reg? RegisterParam register(s) to put the result into, default `true` (route by 'clipboard')
---@field no_notify? boolean skip the yank notification (see `yank.message` config)

---Line range to convert: the visual selection, else the markdown table under the
---cursor, else the block of tab-containing lines around it.
---@return integer?, integer? 1-based start and end lines (inclusive)
local function get_convert_range()
	local cursors = EditTable.get_start_stop_cursors_pos()
	local cur = cursors.current[2]
	if cursors.other_end then
		local other = cursors.other_end[2]
		return math.min(cur, other), math.max(cur, other)
	end
	local table_pos = EditTable.find_closest_markdown_table({ pos = cursors.current, search_mode = "exact" })
	if table_pos then
		return table_pos.line_start, table_pos.line_end
	end

	local function is_tsv(lnum)
		return vim.fn.getline(lnum):find("\t", 1, true) ~= nil
	end
	if not is_tsv(cur) then
		return nil
	end
	local first, last = cur, cur
	while is_tsv(first - 1) do
		first = first - 1
	end
	while is_tsv(last + 1) do
		last = last + 1
	end
	return first, last
end

---Convert lines between a markdown table and TSV
---@param lines string[]
---@param args? ConvertOpts
---@return string[]
function M.convert_lines(lines, args)
	return require("markdown-table.tsv").convert(lines, args)
end

---Convert the table under the cursor/selection between markdown and TSV, in place
---@param args? ConvertOpts
function M.convert_table(args)
	local first, last = get_convert_range()
	exit_visual()
	if not first then
		vim.notify("No markdown table or TSV found")
		return
	end
	local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
	vim.api.nvim_buf_set_lines(0, first - 1, last, false, M.convert_lines(lines, args))
end

---Yank the converted (markdown <-> TSV) table under the cursor/selection into a register
---@param args? YankConvertedArgs
function M.yank_converted(args)
	args = args or {}
	local first, last = get_convert_range()
	exit_visual()
	if not first then
		vim.notify("No markdown table or TSV found")
		return
	end
	local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
	local direction = require("markdown-table.tsv").resolve_direction(lines, args.direction)
	local converted = M.convert_lines(lines, { direction = direction, skip_header = args.skip_header })
	require("markdown-table.registers").lines_to_reg(converted, args.to_reg or true)

	if args.no_notify then
		return
	end
	local message = require("markdown-table.config").options.yank.message({
		count = #converted,
		direction = direction,
		skip_header = args.skip_header == true,
	})
	if message then
		vim.notify(message)
	end
end

---MarkdownTable plugin initializer
---@param opts? MarkdownTablePluginConfig
function M.setup(opts)
	require("markdown-table.config").setup(opts)
end

return M
