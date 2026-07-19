local M = {}

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
	local make_header_cont = function(v)
		return string.format("Header %d", v)
	end

	if x <= 0 then
		return {}
	end

	if opts.max_width and x > opts.max_width then
		x = opts.max_width --[[@as integer]]
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
	local row_cont = string.rep(" ", header_cont_size)
	for _ = 1, y do
		table.insert(lines, markdown_table_row_of(row_cont, x))
	end
	return lines
end

---@class CreateColumnConfig
---@field header? string header text for a generated column, default "Header"

--- Generate a single blank column (column-major cells) for a table of `nrows` lines.
--- Only carries the header text and blanks; width and separator are finalized by the
--- caller's column normalization.
---@param config? CreateColumnConfig
---@param nrows integer number of lines in the target table (header + separator + body)
---@return string[] column-major cells
function M.create_column(config, nrows)
	config = config or {}
	local header = config.header or "Header"
	local col = { " " .. header .. " " }
	for r = 2, nrows do
		col[r] = ""
	end
	return col
end

return M
