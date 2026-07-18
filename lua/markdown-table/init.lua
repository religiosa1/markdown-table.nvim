local M = {}

---parses input string into two ints for table creation
---@param input string
---@return integer,integer
local function tokenize_create_table_input(input)
	local values = {}
	for token in input:gmatch("[0-9]+") do
		local num = tonumber(token)
		if num ~= nil then
			table.insert(values, num)
		end
		if #values == 2 then
			break
		end
	end
	return values[1], values[2]
end

--- generate a markdown table row of repeated string of a given size
--- @param value string value to repeat
--- @param size integer number of columns
--- @return string
local function markdown_table_row_of(value, size)
	local header_delimiter = "| "
	for i = 1, size do
		header_delimiter = header_delimiter .. value
		if i ~= size then
			header_delimiter = header_delimiter .. " | "
		end
	end
	header_delimiter = header_delimiter .. " |"
	return header_delimiter
end

---creates a markdown table of the specified size
---@param x integer
---@param y integer
---@return string[]
local function create_table_lines(x, y)
	x = x or 1
	local make_header_cont = function(v)
		return string.format("Header %d", v)
	end

	if x <= 0 then
		return {}
	end

	local lines = {}
	-- header first
	local headers = {}
	for i = 1, x do
		table.insert(headers, make_header_cont(i))
	end
	table.insert(lines, "| " .. table.concat(headers, " | ") .. " |")

	local header_cont_size = #headers[1]
	local delim_cont = string.rep("-", header_cont_size)
	table.insert(lines, markdown_table_row_of(delim_cont, x))

	if not y or y < 0 then
		return lines
	end

	-- the main lines now
	local row_cont = string.rep(" ", header_cont_size)
	for _ = 1, y do
		table.insert(lines, markdown_table_row_of(row_cont, x))
	end
	return lines
end

local function read_buffer_line(buf_id, line_num)
	return vim.api.nvim_buf_get_lines(buf_id, line_num - 1, line_num, false)[1]
end

--- Check if a string is a markdown-table-row-like (starts with an optional indent + '|')
--- @param line string
--- @return boolean whether the line looks like a markdown table row
local function is_table_row(line)
	return line ~= nil and line:match("^%s*|") ~= nil
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
local function get_start_stop_cursors_pos()
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

---@class FindMarkdownTableOpts
---@field search_mode SearchMode
---@field pos CursorPosition

--- Search the closest markdown table from the current cursor position
--- @param opts? FindMarkdownTableOpts
--- @return TablePosition? position of table or nil, if nothing was found
local function find_closest_markdown_table(opts)
	opts = opts or {}
	local pos = opts.pos or vim.fn.getcurpos()
	local search_mode = opts.search_mode or "backward"
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
			if not is_table_row(prev_line) then
				break
			end
			best.line_start = best.line_start - 1
		end
		local nlines = vim.api.nvim_buf_line_count(0)
		while best.line_end < nlines do
			local next_line = read_buffer_line(0, best.line_end + 1)
			if not is_table_row(next_line) then
				break
			end
			best.line_end = best.line_end + 1
		end
	end
	return best
end

---@class GetColumnUnderPosOpts
---@field table_pos TablePosition
---@field cursor_pos CursorPosition

---Determines the column index under the cursor.
---The rightmost separator is considered to be the last column. For the rest
---of separators, cursor on the separator is considered to be a part of the col
---next to it.
---@param opts GetColumnUnderPosOpts
---@return integer index of the current column, 1-based. 0 if no column is under a cursor
local function get_column_under_pos(opts)
	local pos = opts.cursor_pos
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

--- Split a table row into segments delimited by unescaped '|'.
--- cells[1] is the text left of the leading pipe (usually indentation), cells[#cells]
--- is the text right of the trailing pipe; the actual columns are cells[2 .. #cells-1].
--- @param line string
--- @return string[]
local function split_row(line)
	-- there's seemingly a discrepancy between how CommonMark and github-flavored
	-- parsers are handling the escaped escapement r'\\|' vs '\|' --
	-- but it's such an edge case that I just ignore it.
	return vim.split(line, "[^\\]?|")
end

--- Rebuild a bordered row from its outer segments and inner columns
--- @param cells string[] cells, as split_row returns it - with left and right extras
--- @return string
local function join_row(cells)
	return table.concat(cells, "|")
end

---@class AddColumnOpts
---@field table_pos TablePosition position of a md table in a buffer
---@field column_idx integer index of a column to add

--- Add a column to a markdown table
--- @param opts AddColumnOpts
local function add_column(opts)
	local header_content = "Header"
	local table_pos = opts.table_pos
	local lines = vim.api.nvim_buf_get_lines(0, table_pos.line_start - 1, table_pos.line_end, false)

	local width = #header_content + 2

	for line_n, line in ipairs(lines) do
		local cells = split_row(line)
		if #cells >= 2 then
			-- deducting 1 garbage cols in the math.min clamp (one because we add another one afterwards)
			local at = math.max(1, math.min(#cells - 1, opts.column_idx)) + 1
			local content
			if line_n == 1 then -- header line
				content = " " .. header_content .. string.rep(" ", width - 1 - #header_content)
			elseif line_n == 2 then -- header separator
				content = " " .. string.rep("-", width - 2) .. " "
			else
				content = string.rep(" ", width)
			end
			table.insert(cells, at, content)
			lines[line_n] = join_row(cells)
		end
	end

	vim.api.nvim_buf_set_lines(0, table_pos.line_start - 1, table_pos.line_end, false, lines)
end

---@class DeleteColumnsOpts
---@field table_pos TablePosition position of the table in a buffer
---@field column_idx integer index of column to remove
---@field to_column_idx? integer end index when removing multiple columns

--- Delete a column or multiple columns in a markdown table
--- @param opts DeleteColumnsOpts
local function delete_column(opts)
	local table_pos = opts.table_pos
	local lines = vim.api.nvim_buf_get_lines(0, table_pos.line_start - 1, table_pos.line_end, false)
	if #lines == 0 then
		return
	end

	local columns = vim.iter(lines)
		:map(function(row)
			return split_row(row)
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

	for idx, cells in ipairs(columns) do
		-- calling remove multiple times for each column to remove, but always providing
		-- the first col idx and just shifting the rest of the table
		for _ = col_idx, end_col_idx do
			if #cells > 3 then -- we have some cell to remove
				table.remove(cells, col_idx + 1)
				lines[idx] = join_row(cells)
			else -- the last cell, just concatenating left-right garbage without a separator
				lines[idx] = cells[1] .. cells[#cells]
				break
			end
		end
	end

	vim.api.nvim_buf_set_lines(0, table_pos.line_start - 1, table_pos.line_end, false, lines)
end

--- check if provided position is inside table position
--- @param pos CursorPosition
--- @param table_pos TablePosition
--- @return boolean
local function is_cursor_inside_table(pos, table_pos)
	return pos[2] >= table_pos.line_start and pos[2] <= table_pos.line_end
end

function M.create_table()
	local opts = require("config")
	local input_str = vim.fn.input({
		prompt = opts.new_table.prompt,
	})
	if not input_str then
		return
	end
	local x, y = tokenize_create_table_input(input_str)
	local lines = create_table_lines(x, y)
	vim.api.nvim_put(lines, "l", true, false)
end

---@class AddColumnArgs
---@field paste_mode? "before" | "after" paste the column before or after current column, default to after
---@field search_mode? SearchMode: where to search for closes table. If not provided, inferred from paste_mode
---@field from_reg? string -- TODO: register to paste from, nil to avoid pasting

---Paste or add column
---@param args? AddColumnArgs
function M.paste_column(args)
	args = args or {}
	local is_paste_after = args.paste_mode ~= "before"
	local search_mode = args.search_mode or (is_paste_after and "forward" or "backward")

	local pos = vim.fn.getcurpos()

	local table_pos = find_closest_markdown_table({
		pos = pos,
		search_mode = search_mode,
	})
	if table_pos == nil then
		vim.notify("No markdown table found")
		return
	end

	local column_idx = is_cursor_inside_table(pos, table_pos)
			and get_column_under_pos({
				table_pos = table_pos,
				cursor_pos = pos,
			})
		or (is_paste_after and math.huge or 0)

	if is_paste_after and column_idx ~= math.huge then
		column_idx = column_idx + 1
	end
	add_column({
		table_pos = table_pos,
		column_idx = column_idx,
	})
end

---@class DeleteColumnArgs
---@field search_mode? SearchMode: where to search for closes table. If not provided, inferred from paste_mode
---@field to_reg? string -- TODO: register to yank into, nil to avoid pasting
function M.delete_column()
	local cursors = get_start_stop_cursors_pos()

	local table_pos = find_closest_markdown_table({
		pos = cursors.current,
		search_mode = "exact",
	})
	if table_pos == nil then
		vim.notify("No markdown table found")
		return
	end
	local current_column = get_column_under_pos({
		table_pos = table_pos,
		cursor_pos = cursors.current,
	})
	local end_column
	if cursors.other_end ~= nil then
		end_column = get_column_under_pos({
			table_pos = table_pos,
			cursor_pos = cursors.other_end,
		})
	end
	delete_column({
		table_pos = table_pos,
		column_idx = current_column,
		to_column_idx = end_column or current_column,
	})
end

return M
