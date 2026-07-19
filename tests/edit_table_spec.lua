local ET = require("markdown-table.edit-table")
local CreateTable = require("markdown-table.create-table")
local R = require("markdown-table.registers")

local function set_buf(lines)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end
local function get_buf()
	return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

describe("create_table.create_column", function()
	it("makes a header cell plus blanks for nrows", function()
		assert.same({ " Header ", "", "" }, CreateTable.create_column(nil, 3))
	end)

	it("honors a custom header", function()
		assert.same({ " Foo ", "", "", "" }, CreateTable.create_column({ header = "Foo" }, 4))
	end)
end)

describe("edit_table.add_column", function()
	it("appends a generated blank column, aligned", function()
		set_buf({ "| A | B |", "| - | - |", "| 1 | 2 |" })
		ET.add_column({ table_pos = { line_start = 1, line_end = 3 }, column_idx = 3 })
		assert.same({
			"| A | B | Header |",
			"| - | - | ------ |",
			"| 1 | 2 |        |",
		}, get_buf())
	end)

	it("expands a too-short pasted column to the table height", function()
		set_buf({ "| A |", "| - |", "| 1 |", "| 2 |" })
		-- one column, only the header cell provided
		ET.add_column({ table_pos = { line_start = 1, line_end = 4 }, column_idx = 2, columns = { { " X " } } })
		-- MIN_COL_WIDTH is 5, so " X " widens to a 5-char cell
		assert.same({
			"| A | X   |",
			"| - | --- |",
			"| 1 |     |",
			"| 2 |     |",
		}, get_buf())
	end)
end)

describe("delete -> register -> paste round-trip", function()
	it("restores the original table", function()
		local original = {
			"| Header 1 | Header 2 | Header 3 |",
			"| -------- | -------- | -------- |",
			"| Foo      | Bar      | Biz      |",
			"| Lorus    | Ipsum    | Blah     |",
		}
		set_buf(original)
		local table_pos = { line_start = 1, line_end = 4 }

		local deleted = ET.delete_column({ table_pos = table_pos, column_idx = 2, to_column_idx = 2 })
		R.cols_to_reg(deleted, "z")

		ET.add_column({ table_pos = table_pos, column_idx = 2, columns = R.cols_from_reg("z") })
		assert.same(original, get_buf())
	end)
end)
