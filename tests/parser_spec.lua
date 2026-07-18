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
