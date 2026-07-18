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

--- Rebuild a bordered row from its outer segments and inner columns
--- @param cells string[] cells, as split_row returns it - with left and right extras
--- @return string
function M.join_row(cells)
	return table.concat(cells, "|")
end

return M
