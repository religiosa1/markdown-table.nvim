local TableParser = require("markdown-table.parser")

local M = {}

local function read_buffer_line(buf_id, line_num)
	return vim.api.nvim_buf_get_lines(buf_id, line_num - 1, line_num, false)[1]
end

---Cursor position tuple. (as getpos returns it)
---1. `bufnum` - buffer number
---2. `lnum` - line number (1-indexed)
---3. `col` - column number (0-indexed)
---4. `off` - virtual offset
---@alias CursorPosition [integer, integer, integer, integer ]

--- @class SelectionCursorsPosition
--- @field current CursorPosition current cursor position
--- @field other_end? CursorPosition "other end" of selection in visual mode

local visual_modes = { v = true, V = true, ["\22"] = true } -- \22 is <C-v>, blockwise

--- get start-stop cursors position in visual mode, or current cursor in other modes
--- @return SelectionCursorsPosition
function M.get_start_stop_cursors_pos()
	---@type SelectionCursorsPosition
	local cursors = {
		current = vim.fn.getpos("."),
	}
	if visual_modes[vim.fn.mode()] then
		cursors.other_end = vim.fn.getpos("v")
	end
	return cursors
end

---@class TablePosition position of a markdown table in a buffer
---@field line_start integer 1-based line of the header row
---@field line_end integer 1-based line of the last table row (inclusive)

--- How to search for a table - forward or backward of cursor, or cursor must be exactly in a table
---@alias SearchMode 'forward' | 'backward' | 'exact'

---@class FindMarkdownTableArgs
---@field search_mode SearchMode
---@field pos CursorPosition

--- Search the closest markdown table from the current cursor position
--- @param args? FindMarkdownTableArgs
--- @return TablePosition? position of table or nil, if nothing was found
function M.find_closest_markdown_table(args)
	args = args or {}
	local pos = args.pos or vim.fn.getcurpos()
	local search_mode = args.search_mode or "backward"
	local cur = pos[2] - 1 -- 0-based cursor row

	local ok, parser = pcall(vim.treesitter.get_parser, 0, "markdown")
	if not ok or parser == nil then
		return nil
	end
	local trees = parser:parse()
	if trees == nil or trees[1] == nil then
		return nil
	end
	local root = trees[1]:root()
	local query = vim.treesitter.query.parse("markdown", "(pipe_table) @table")

	local best, best_dist = nil, nil
	for _, node in query:iter_captures(root, 0) do
		local sr, _, er, ec = node:range()
		-- a pipe_table's end usually points at the start of the following line
		local last = (ec == 0 and er > sr) and (er - 1) or er

		local candidate, dist = false, nil
		if cur >= sr and cur <= last then
			candidate, dist = true, 0
		elseif search_mode == "backward" and last < cur then
			candidate, dist = true, cur - last
		elseif search_mode == "forward" and sr > cur then
			candidate, dist = true, sr - cur
		end

		if candidate and (best_dist == nil or dist < best_dist) then
			best_dist = dist
			best = { line_start = sr + 1, line_end = last + 1 }
		end
	end

	-- whitespace-only cells make the markdown grammar split one visual table into several
	-- pipe_table nodes, so grow the range over the whole contiguous block of table rows
	if best then
		while best.line_start > 0 do
			local prev_line = read_buffer_line(0, best.line_start - 1)
			if not TableParser.is_table_row(prev_line) then
				break
			end
			best.line_start = best.line_start - 1
		end
		local nlines = vim.api.nvim_buf_line_count(0)
		while best.line_end < nlines do
			local next_line = read_buffer_line(0, best.line_end + 1)
			if not TableParser.is_table_row(next_line) then
				break
			end
			best.line_end = best.line_end + 1
		end
	end
	return best
end

---@class GetColumnUnderPosArgs
---@field table_pos TablePosition
---@field cursor_pos CursorPosition

---Determines the column index under the cursor.
---The rightmost separator is considered to be the last column. For the rest
---of separators, cursor on the separator is considered to be a part of the col
---next to it.
---@param args GetColumnUnderPosArgs
---@return integer index of the current column, 1-based. 0 if no column is under a cursor
function M.get_column_under_pos(args)
	local pos = args.cursor_pos
	local row = pos[2] - 1 -- 0-based
	local col = pos[3] -- 1-based byte column of the cursor
	local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
	if line == nil then
		return 0
	end

	-- trimming the rightmost separator on the right
	line = line:gsub("[^\\]|[^|]*$", "")

	-- count unescaped '|' at or before the cursor; a pipe belongs to the cell on its right,
	-- so the leading pipe yields column 1
	local count = 0
	local i = 1
	while i <= col do
		local c = line:sub(i, i)
		if c == "\\" then
			i = i + 2 -- skip the escaped char
		else
			if c == "|" then
				count = count + 1
			end
			i = i + 1
		end
	end
	return count
end

---@class AddColumnArgs
---@field table_pos TablePosition position of a md table in a buffer
---@field column_idx integer index of a column to add

--- Add a column to a markdown table
--- @param args AddColumnArgs
function M.add_column(args)
	local header_content = "Header"
	local table_pos = args.table_pos
	local lines = vim.api.nvim_buf_get_lines(0, table_pos.line_start - 1, table_pos.line_end, false)

	local width = #header_content + 2

	for line_n, line in ipairs(lines) do
		local cells = TableParser.split_row(line)
		if #cells >= 2 then
			-- deducting 1 garbage cols in the math.min clamp (one because we add another one afterwards)
			local at = math.max(1, math.min(#cells - 1, args.column_idx)) + 1
			local content
			if line_n == 1 then -- header line
				content = " " .. header_content .. string.rep(" ", width - 1 - #header_content)
			elseif line_n == 2 then -- header separator
				content = " " .. string.rep("-", width - 2) .. " "
			else
				content = string.rep(" ", width)
			end
			table.insert(cells, at, content)
			lines[line_n] = TableParser.join_row(cells)
		end
	end

	vim.api.nvim_buf_set_lines(0, table_pos.line_start - 1, table_pos.line_end, false, lines)
end

---@class DeleteColumnsArgs
---@field table_pos TablePosition position of the table in a buffer
---@field column_idx integer index of column to remove
---@field to_column_idx? integer end index when removing multiple columns

--- Delete a column or multiple columns in a markdown table
--- @param opts DeleteColumnsArgs
--- @return string[][] deleted columns, column-major (see parser.pluck_columns)
function M.delete_column(opts)
	local table_pos = opts.table_pos
	local lines = vim.api.nvim_buf_get_lines(0, table_pos.line_start - 1, table_pos.line_end, false)
	if #lines == 0 then
		return
	end

	local columns = vim.iter(lines)
		:map(function(row)
			return TableParser.split_row(row)
		end)
		:totable()

	-- Maybe do that on per cell basis in the loop below? To account for messed up tables
	local ncols = vim.iter(columns):fold(0, function(acc, cur)
		-- -2 for left and right garbage before and after a row
		return math.max(acc, #cur - 2)
	end)

	local col_idx = math.max(1, math.min(ncols, opts.column_idx))
	local end_col_idx = math.max(1, math.min(ncols, opts.to_column_idx or opts.column_idx))
	if end_col_idx < col_idx then
		col_idx, end_col_idx = end_col_idx, col_idx
	end

	-- pluck before the loop below mutates `columns` in place
	local deleted = TableParser.pluck_columns(columns, col_idx, end_col_idx)

	for idx, cells in ipairs(columns) do
		-- calling remove multiple times for each column to remove, but always providing
		-- the first col idx and just shifting the rest of the table
		for _ = col_idx, end_col_idx do
			if #cells > 3 then -- we have some cell to remove
				table.remove(cells, col_idx + 1)
				lines[idx] = TableParser.join_row(cells)
			else -- the last cell, just concatenating left-right garbage without a separator
				lines[idx] = cells[1] .. cells[#cells]
				break
			end
		end
	end

	vim.api.nvim_buf_set_lines(0, table_pos.line_start - 1, table_pos.line_end, false, lines)
	return deleted
end

--- check if provided position is inside table position
--- @param pos CursorPosition
--- @param table_pos TablePosition
--- @return boolean
function M.is_cursor_inside_table(pos, table_pos)
	return pos[2] >= table_pos.line_start and pos[2] <= table_pos.line_end
end

return M
