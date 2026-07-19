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
	local regs = { '"' }
	local clip = {}
	for _, v in ipairs(vim.split(vim.o.clipboard or "", ",", { trimempty = true })) do
		clip[v] = true
	end
	if clip.unnamedplus then
		table.insert(regs, "+")
	end
	if clip.unnamed then
		table.insert(regs, "*")
	end
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
	local lines = columns_to_lines(columns)
	for _, name in ipairs(resolve_registers(reg)) do
		vim.fn.setreg(name, lines, "l")
	end
end

--- Read column-major cells back from a register.
--- With a list/`true` spec, reads the first register that holds content.
--- @param reg RegisterParam
--- @return string[][] columns column-major cells
function M.cols_from_reg(reg)
	local lines = {}
	for _, name in ipairs(resolve_registers(reg)) do
		local content = vim.fn.getreg(name, 1, true)
		if content and not (#content == 0 or (#content == 1 and content[1] == "")) then
			lines = content
			break
		end
	end
	return lines_to_columns(lines)
end

return M
