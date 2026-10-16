local TableParser = require("markdown-table.parser")

local M = {}

--- A register spec: a name, a list of names, or a boolean.
--- `true` routes by 'clipboard' (see resolve_registers).
---@alias RegisterParam string | string[] | boolean

--- Resolve a register spec into a list of register names.
--- `true` mirrors vim's own routing from 'clipboard': always the unnamed `"`,
--- plus `+` when 'unnamedplus' is set and `*` when 'unnamed' is set, so a column
--- cut lands wherever the user's clipboard config later pastes from.
--- @param spec RegisterParam
--- @return string[]
local function resolve_registers(spec)
	if type(spec) == "string" then
		return { spec }
	end
	if type(spec) == "table" then
		return spec
	end
	-- boolean true
	-- clipboard regs first: getreg('"') reads vim's internal register, not the
	-- clipboard, so a stale yank there would shadow an external copy on read
	local regs = {}
	local clip = vim.opt.clipboard:get()
	if vim.tbl_contains(clip, "unnamedplus") then
		table.insert(regs, "+")
	end
	if vim.tbl_contains(clip, "unnamed") then
		table.insert(regs, "*")
	end
	table.insert(regs, '"')
	return regs
end

--- Transpose column-major cells into borderless row strings.
--- @param columns string[][]
--- @return string[]
local function columns_to_lines(columns)
	local nrows = columns[1] and #columns[1] or 0
	local lines = {}
	for r = 1, nrows do
		local row = {}
		for c = 1, #columns do
			row[c] = columns[c][r] or ""
		end
		lines[r] = TableParser.join_inner(row)
	end
	return lines
end

--- Transpose borderless row strings back into column-major cells.
--- @param lines string[]
--- @return string[][]
local function lines_to_columns(lines)
	local columns = {}
	for r, line in ipairs(lines) do
		-- register lines have no outer border, so every segment is a real column
		for c, cell in ipairs(TableParser.split_row(line)) do
			columns[c] = columns[c] or {}
			columns[c][r] = cell
		end
	end
	return columns
end

--- Store column-major cells into register(s) as a borderless sub-table.
--- @param columns string[][] column-major cells (as delete_column returns)
--- @param reg RegisterParam
function M.cols_to_reg(columns, reg)
	M.lines_to_reg(columns_to_lines(columns), reg)
end

--- Store plain lines into register(s), linewise.
--- @param lines string[]
--- @param reg RegisterParam
function M.lines_to_reg(lines, reg)
	for _, name in ipairs(resolve_registers(reg)) do
		vim.fn.setreg(name, lines, "l")
	end
end

--- Read column-major cells back from a register.
--- With a list/`true` spec, reads the first register that holds content.
--- @param reg RegisterParam
--- @return string[][] columns column-major cells
function M.cols_from_reg(reg)
	for _, name in ipairs(resolve_registers(reg)) do
		local content = vim.fn.getreg(name, 1, true)
		if content and not (#content == 0 or (#content == 1 and content[1] == "")) then
			return lines_to_columns(content)
		end
	end
	return {}
end

--- How to treat pasted content that has no header separator on its 2nd row:
--- "header" - the first line is the header, a separator is inserted after it;
--- "body" - every line is body, a blank header and a separator are prepended.
---@alias MissingSeparatorMode "header" | "body"

--- @param cell string?
--- @return boolean
local function is_separator_cell(cell)
	return cell ~= nil and cell:match("^%s*:?%-+:?%s*$") ~= nil
end

--- Add a header separator to pasted columns lacking one (e.g. copied from a doc),
--- so the table's separator row doesn't overwrite a real cell.
--- @param columns string[][] column-major cells, modified in place
--- @param mode MissingSeparatorMode
--- @return string[][] columns
function M.add_missing_separator(columns, mode)
	local has_separator = #columns > 0
		and vim.iter(columns):all(function(col)
			return is_separator_cell(col[2])
		end)
	if has_separator then
		return columns
	end
	for _, col in ipairs(columns) do
		if mode == "body" then
			table.insert(col, 1, "")
			table.insert(col, 2, "")
		else
			table.insert(col, 2, "")
		end
	end
	return columns
end

return M
