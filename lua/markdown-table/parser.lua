local M = {}

--- Check if a string is a markdown-table-row-like (starts with an optional indent + `|`)
--- @param line string? line to test, nil is treated as not-a-row
--- @return boolean value of whether the line looks like a markdown table row
function M.is_table_row(line)
	return line ~= nil and line:match("^%s*|") ~= nil
end

--- Split a table row into segments delimited by unescaped `|`.
--- `cells[1]` is the text left of the leading pipe (usually indentation), `cells[#cells]`
--- is the text right of the trailing pipe; the actual columns are `cells[2 .. #cells-1]`.
--- @param line string
--- @return string[]
function M.split_row(line)
	-- byte scan so a `\|` stays inside its cell, and the char before each pipe is
	-- kept (a regex split would eat both). there's seemingly a discrepancy between
	-- how CommonMark and github-flavored parsers handle r'\\|' vs '\|', but it's
	-- such an edge case that I just ignore it.
	local cells = {}
	local seg_start = 1
	local pos = 1
	while pos <= #line do
		local c = line:sub(pos, pos)
		if c == "\\" then
			pos = pos + 2 -- skip the escaped char
		elseif c == "|" then
			table.insert(cells, line:sub(seg_start, pos - 1))
			seg_start = pos + 1
			pos = pos + 1
		else
			pos = pos + 1
		end
	end
	table.insert(cells, line:sub(seg_start))
	return cells
end

--- The inner columns of a bordered row (`split_row` minus the outer extras).
--- @param line string
--- @return string[]
function M.split_inner(line)
	local cells = M.split_row(line)
	return { unpack(cells, 2, #cells - 1) }
end

--- Join cells with `|`. Inner cells only yields a borderless row; a full `split_row`
--- list (empty outer extras included) yields a bordered row. Same op either way, so a
--- borderless register block and a real table row can't drift apart.
--- @param cells string[]
--- @return string
function M.join_inner(cells)
	return table.concat(cells, "|")
end

-- This is literally the same thing, but just keeping it here for semantic difference
--
--- Rebuild a bordered row from a full `split_row` list (outer extras + inner columns).
--- @param cells string[] cells, as split_row returns it - with left and right extras
--- @return string
M.join_row = M.join_inner

--- Pluck a range of inner columns from already-split rows into a column-major 2d list.
--- `result[i]` is the i-th plucked column: its cell for every input row (header,
--- separator, body). Serialization to/from a register lives in the `registers` module.
--- @param rows string[][] each element is a `split_row` result for one line
--- @param from integer 1-based inner column index (inclusive)
--- @param to integer 1-based inner column index (inclusive)
--- @return string[][] column-major cells
function M.pluck_columns(rows, from, to)
	local columns = {}
	for _, cells in ipairs(rows) do
		for c = from, to do
			local col = c - from + 1
			columns[col] = columns[col] or {}
			-- inner column c lives at cells[c + 1] (cells[1] is the left extra)
			columns[col][#columns[col] + 1] = cells[c + 1] or ""
		end
	end
	return columns
end

return M
