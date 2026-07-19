local parser = require("markdown-table.parser")

describe("parser.is_table_row", function()
	it("accepts a bordered row", function()
		assert.is_true(parser.is_table_row("| a | b |"))
	end)

	it("accepts a leading-indent row", function()
		assert.is_true(parser.is_table_row("   | a | b |"))
	end)

	it("rejects a non-table line", function()
		assert.is_false(parser.is_table_row("hello world"))
	end)

	it("rejects nil", function()
		assert.is_false(parser.is_table_row(nil))
	end)

	it("rejects a pipe that is not the first non-space char", function()
		assert.is_false(parser.is_table_row("a | b"))
	end)
end)

describe("parser split_row/join_row round-trip", function()
	-- split_row's contract: cells[1] is the left extra, cells[#cells] the right extra,
	-- columns are cells[2 .. #cells-1]. join_row must reproduce the original line.
	local function roundtrip(line)
		return parser.join_row(parser.split_row(line))
	end

	it("splits into left extra, columns, right extra", function()
		local cells = parser.split_row("| a | b |")
		assert.same({ "", " a ", " b ", "" }, cells)
	end)

	it("preserves leading indentation as the left extra", function()
		local cells = parser.split_row("  | a | b |")
		assert.equals("  ", cells[1])
	end)

	it("round-trips a plain row", function()
		assert.equals("| a | b |", roundtrip("| a | b |"))
	end)

	it("round-trips an indented row", function()
		assert.equals("   | a | b |", roundtrip("   | a | b |"))
	end)

	it("round-trips preserving inner whitespace", function()
		assert.equals("|  wide  | x |", roundtrip("|  wide  | x |"))
	end)

	it("does not split on an escaped pipe", function()
		-- `\|` is a literal pipe inside a cell, not a column separator.
		local cells = parser.split_row([[| a\|b | c |]])
		assert.same({ "", [[ a\|b ]], " c ", "" }, cells)
	end)

	it("round-trips a row containing an escaped pipe", function()
		assert.equals([[| a\|b | c |]], roundtrip([[| a\|b | c |]]))
	end)
end)

describe("parser.split_inner", function()
	it("returns only the inner columns of a bordered row", function()
		assert.same({ " a ", " b " }, parser.split_inner("| a | b |"))
	end)

	it("drops leading indentation with the outer extras", function()
		assert.same({ " a ", " b " }, parser.split_inner("   | a | b |"))
	end)
end)

describe("parser.join_inner", function()
	it("joins cells borderless, no outer pipes", function()
		assert.equals(" a | b ", parser.join_inner({ " a ", " b " }))
	end)

	it("is the same op as join_row", function()
		assert.equals(parser.join_inner, parser.join_row)
	end)
end)

describe("parser.pluck_columns", function()
	-- a table's rows, already run through split_row
	local rows = {
		parser.split_row("| Header 1 | Header 2 | Header 3 |"),
		parser.split_row("| -------- | -------- | -------- |"),
		parser.split_row("| Foo      | Bar      | Biz      |"),
		parser.split_row("| Lorus    | Ipsum    | Blah     |"),
	}

	it("plucks a single column, column-major", function()
		assert.same({
			{ " Header 2 ", " -------- ", " Bar      ", " Ipsum    " },
		}, parser.pluck_columns(rows, 2, 2))
	end)

	it("plucks a range as one entry per column", function()
		assert.same({
			{ " Header 2 ", " -------- ", " Bar      ", " Ipsum    " },
			{ " Header 3 ", " -------- ", " Biz      ", " Blah     " },
		}, parser.pluck_columns(rows, 2, 3))
	end)

	it("fills cells past a row's width with empty strings", function()
		local ragged = { parser.split_row("| a |") } -- one real column
		-- column 1 -> " a ", column 2 -> the right extra "" (range clamped by caller normally)
		assert.same({ { " a " }, { "" } }, parser.pluck_columns(ragged, 1, 2))
	end)
end)
