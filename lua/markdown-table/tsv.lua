local TableParser = require("markdown-table.parser")

local M = {}

---@alias ConvertDirection "auto" | "to_tsv" | "to_markdown"

--- A markdown header separator row, e.g. `| --- | :-: |`
--- @param line string
--- @return boolean
local function is_separator_row(line)
	return line:match("^%s*|[%s|:%-]*$") ~= nil and line:find("-", 1, true) ~= nil
end

--- Markdown table rows into TSV lines. Header stays as the first row; the separator
--- (with its alignment) is dropped. Cells are trimmed and `\|` unescaped.
--- Only the second row can be a separator, so a body row of `-` (n/a) cells survives.
--- @param lines string[]
--- @param skip_header? boolean drop the header row too
--- @return string[]
function M.to_tsv(lines, skip_header)
	local out = {}
	local row_n = 0
	for _, line in ipairs(lines) do
		if TableParser.is_table_row(line) then
			row_n = row_n + 1
			if not (row_n == 2 and is_separator_row(line)) then
				local cells = vim.tbl_map(function(cell)
					return (vim.trim(cell):gsub("\\|", "|"))
				end, TableParser.split_inner(line))
				table.insert(out, table.concat(cells, "\t"))
			end
		end
	end
	if skip_header then
		table.remove(out, 1)
	end
	return out
end

--- TSV lines into an aligned markdown table; the first row becomes the header.
--- Short rows are padded, `|` is escaped. Blank lines are skipped.
--- @param lines string[]
--- @return string[]
function M.to_markdown(lines)
	local rows, widths = {}, {}
	for _, line in ipairs(lines) do
		if vim.trim(line) ~= "" then
			local cells = vim.split(line, "\t", { plain = true })
			for c, cell in ipairs(cells) do
				-- NOTE: a `\` before `|` in TSV becomes `\\|`, which split_row reads as an escaped
				-- backslash plus a delimiter; ignored as in parser.split_row.
				cells[c] = (vim.trim(cell):gsub("|", "\\|"))
				widths[c] = math.max(widths[c] or 3, vim.fn.strdisplaywidth(cells[c]))
			end
			table.insert(rows, cells)
		end
	end
	if #rows == 0 then
		return {}
	end

	local function render(cells)
		local padded = {}
		for c, width in ipairs(widths) do
			local cell = cells[c] or ""
			padded[c] = cell .. string.rep(" ", width - vim.fn.strdisplaywidth(cell))
		end
		return "| " .. table.concat(padded, " | ") .. " |"
	end

	local out = { render(rows[1]) }
	out[2] = render(vim.tbl_map(function(width)
		return string.rep("-", width)
	end, widths))
	for r = 2, #rows do
		out[r + 1] = render(rows[r])
	end
	return out
end

--- Markdown if the first non-blank line is a table row, TSV otherwise.
--- @param lines string[]
--- @return boolean
function M.is_markdown(lines)
	for _, line in ipairs(lines) do
		if vim.trim(line) ~= "" then
			return TableParser.is_table_row(line)
		end
	end
	return false
end

--- Resolve "auto" (or nil) into the actual direction for these lines.
--- @param lines string[]
--- @param direction? ConvertDirection
--- @return "to_tsv" | "to_markdown"
function M.resolve_direction(lines, direction)
	if direction == nil or direction == "auto" then
		return M.is_markdown(lines) and "to_tsv" or "to_markdown"
	end
	return direction
end

---@class ConvertOpts
---@field direction? ConvertDirection default "auto": picked by `is_markdown`
---@field skip_header? boolean drop the header row when converting to TSV

--- Convert between a markdown table and TSV.
--- @param lines string[]
--- @param opts? ConvertOpts
--- @return string[]
function M.convert(lines, opts)
	opts = opts or {}
	if M.resolve_direction(lines, opts.direction) == "to_tsv" then
		return M.to_tsv(lines, opts.skip_header)
	end
	return M.to_markdown(lines)
end

return M
