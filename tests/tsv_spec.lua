local Tsv = require("markdown-table.tsv")
local MdTable = require("markdown-table")

local markdown = {
	"| Name  | Pipe     |",
	"| :---- | -------: |",
	"| Foo   | a \\| b   |",
	"| Bar   |          |",
}
local tsv = {
	"Name\tPipe",
	"Foo\ta | b",
	"Bar\t",
}

describe("tsv.convert", function()
	it("markdown -> tsv: drops separator, trims, unescapes pipes", function()
		assert.same(tsv, Tsv.convert(markdown))
	end)

	it("tsv -> markdown: aligns, escapes pipes, pads short rows", function()
		assert.same({
			"| Name | Pipe   | Extra |",
			"| ---- | ------ | ----- |",
			"| Foo  | a \\| b |       |",
			"| Bar  |        |       |",
		}, Tsv.convert({ "Name\tPipe\tExtra", "Foo\ta | b", "", "Bar" }))
	end)

	it("markdown -> tsv: keeps body rows that look like a separator", function()
		assert.same({ "a\tb", "-\t", "1\t2" }, Tsv.convert({ "| a | b |", "| - | - |", "| - |   |", "| 1 | 2 |" }))
	end)

	it("markdown -> tsv: optionally skips the header", function()
		assert.same({ tsv[2], tsv[3] }, Tsv.convert(markdown, { skip_header = true }))
	end)

	it("round-trips tsv", function()
		assert.same(tsv, Tsv.convert(Tsv.convert(tsv)))
	end)

	it("honors a forced direction", function()
		-- looks like markdown, but forced to be read as TSV
		assert.same({ "| \\| x \\| |", "| ------- |" }, Tsv.convert({ "| x |" }, { direction = "to_markdown" }))
	end)
end)

describe("convert_table / yank_converted", function()
	before_each(function()
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "intro", "a\tb", "1\t2", "", "outro" })
		vim.fn.cursor(3, 1)
	end)

	it("converts the TSV block under the cursor in place", function()
		MdTable.convert_table()
		assert.same({
			"intro",
			"| a   | b   |",
			"| --- | --- |",
			"| 1   | 2   |",
			"",
			"outro",
		}, vim.api.nvim_buf_get_lines(0, 0, -1, false))
	end)

	it("yanks the conversion without touching the buffer", function()
		MdTable.yank_converted({ to_reg = "z", no_notify = true })
		assert.same({ "| a   | b   |", "| --- | --- |", "| 1   | 2   |" }, vim.fn.getreg("z", 1, true))
		assert.same("a\tb", vim.api.nvim_buf_get_lines(0, 1, 2, false)[1])
	end)

	it("notifies with the configured message", function()
		local notify, messages = vim.notify, {}
		vim.notify = function(msg)
			table.insert(messages, msg)
		end
		MdTable.yank_converted({ to_reg = "z" })
		require("markdown-table").setup({
			yank = {
				message = function(info)
					return info.direction .. " " .. info.count
				end,
			},
		})
		MdTable.yank_converted({ to_reg = "z" })
		require("markdown-table").setup()
		vim.notify = notify
		assert.same({ "Yanked 3 markdown table lines", "to_markdown 3" }, messages)
	end)
end)
