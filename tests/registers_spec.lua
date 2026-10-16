local registers = require("markdown-table.registers")

describe("registers cols_to_reg / cols_from_reg", function()
	-- column-major, as delete_column returns
	local columns = {
		{ " Header 2 ", " -------- ", " Bar      ", " Ipsum    " },
		{ " Header 3 ", " -------- ", " Biz      ", " Blah     " },
	}

	it("writes a borderless sub-table into the register (linewise)", function()
		registers.cols_to_reg(columns, "z")
		assert.equals("V", vim.fn.getregtype("z"))
		assert.same({
			" Header 2 | Header 3 ",
			" -------- | -------- ",
			" Bar      | Biz      ",
			" Ipsum    | Blah     ",
		}, vim.fn.getreg("z", 1, true))
	end)

	it("round-trips columns through a register", function()
		registers.cols_to_reg(columns, "z")
		assert.same(columns, registers.cols_from_reg("z"))
	end)

	it("round-trips a single column", function()
		local one = { { " Header 2 ", " -------- ", " Bar      " } }
		registers.cols_to_reg(one, "z")
		assert.same(one, registers.cols_from_reg("z"))
	end)

	it("writes to every register in a list", function()
		registers.cols_to_reg(columns, { "z", "x" })
		assert.same(vim.fn.getreg("z", 1, true), vim.fn.getreg("x", 1, true))
		assert.same(columns, registers.cols_from_reg("x"))
	end)

	it("reads the first non-empty register from a list", function()
		vim.fn.setreg("z", "", "l") -- empty
		registers.cols_to_reg(columns, "x")
		assert.same(columns, registers.cols_from_reg({ "z", "x" }))
	end)
end)

describe("registers add_missing_separator", function()
	it("keeps columns that already have a separator", function()
		local cols = { { " H ", " --- ", " a " } }
		assert.same({ { " H ", " --- ", " a " } }, registers.add_missing_separator(cols, "header"))
	end)

	it("accepts alignment colons in a separator", function()
		local cols = { { "H", ":-:", "a" }, { "G", "---:", "b" } }
		assert.same({ { "H", ":-:", "a" }, { "G", "---:", "b" } }, registers.add_missing_separator(cols, "header"))
	end)

	it("header mode: first line becomes the header", function()
		local cols = { { "1", "2", "3" } }
		assert.same({ { "1", "", "2", "3" } }, registers.add_missing_separator(cols, "header"))
	end)

	it("body mode: blank header, every line in the body", function()
		local cols = { { "1", "2", "3" } }
		assert.same({ { "", "", "1", "2", "3" } }, registers.add_missing_separator(cols, "body"))
	end)

	it("treats a partial separator row as missing", function()
		local cols = { { "H", "---" }, { "G", "x" } }
		assert.same({ { "H", "", "---" }, { "G", "", "x" } }, registers.add_missing_separator(cols, "header"))
	end)
end)
