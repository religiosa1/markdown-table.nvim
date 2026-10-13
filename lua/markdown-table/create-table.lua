local M = {}

---@alias HeaderFormat string | fun(idx: integer): string format string (`%d` is the column index) or a function

---@param header HeaderFormat
---@param idx integer column index
---@return string
local function format_header(header, idx)
	if type(header) == "function" then
		return header(idx)
	end
	return string.format(header, idx)
end

---parses input string into two ints for table creation
---@param input string
---@return integer,integer
function M.tokenize_create_table_input(input)
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

---creates a markdown table of the specified size
---@param x integer
---@param y integer
---@param opts? CreateTableConfig extra configuration options
---@return string[]
function M.create_table_lines(x, y, opts)
	opts = opts or {}
	x = x or 1
	local header = opts.header or "Header%d"

	if x <= 0 then
		return {}
	end

	if opts.max_width and x > opts.max_width then
		x = opts.max_width --[[@as integer]]
	end

	local lines = {}
	-- header first; widths vary per column (Header9 vs Header10, custom formats)
	local headers, delims, blanks = {}, {}, {}
	for i = 1, x do
		local cont = format_header(header, i)
		local width = math.max(3, #cont) -- separator needs at least 3 dashes
		headers[i] = cont .. string.rep(" ", width - #cont)
		delims[i] = string.rep("-", width)
		blanks[i] = string.rep(" ", width)
	end
	table.insert(lines, "| " .. table.concat(headers, " | ") .. " |")
	table.insert(lines, "| " .. table.concat(delims, " | ") .. " |")

	if y == nil then
		y = opts.default_n_lines
	end

	if not y or y < 0 then
		return lines
	end

	if opts.max_height and y > opts.max_height then
		y = opts.max_height
	end

	-- the main lines now
	local row = "| " .. table.concat(blanks, " | ") .. " |"
	for _ = 1, y do
		table.insert(lines, row)
	end
	return lines
end

---@class CreateColumnConfig
---@field header? HeaderFormat header of a generated column, default "Header"

--- Generate a single blank column (column-major cells) for a table of `nrows` lines.
--- Only carries the header text and blanks; width and separator are finalized by the
--- caller's column normalization.
---@param config? CreateColumnConfig
---@param nrows integer number of lines in the target table (header + separator + body)
---@param idx integer column index of the new column, for the header format
---@return string[] column-major cells
function M.create_column(config, nrows, idx)
	config = config or {}
	local header = format_header(config.header or "Header", idx)
	local col = { " " .. header .. " " }
	for r = 2, nrows do
		col[r] = ""
	end
	return col
end

return M
