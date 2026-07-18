# Markdown Table

Neovim plugin for some actions for editing markdown tables.

It provides actions to:

- Delete/cut columns
- Paste column
- Add columns (ignoring the registers)
- Generate a table stub of provided width/height

It only provides actions for the tables editing, nothing else. All actions can
be undone.

For the full smorgasbord of various markdown editing actions (including table
edits) look at [markdown-plus](https://github.com/YousefHadder/markdown-plus.nvim).

I prefer my plugins to be smaller in scope, and I don't need most of the
features of that plugin, and want to avoid potential interactions with other
rendering and editing plugins, hence this.

#### Why no add/delete rows?

Because it's basically just add or delete a line and a bunch of `|` inside, I
don't see it's worth it. Just do `dd`/`o`/`O`.

## How it works?

This plugin uses treesitter to get the position of a nearest table in a
markdown document. The rest of logic is basically splitting/joining by the `|`
character. There's some limited support for escaped `\|` in cells.

## Installation

### Lazy:

(require is inside of handler, to ensure proper lazy loading)

```lua
{
  "religiosa1/markdown-table.nvim",
  lazy = true,
  ft = { "markdown", "text", "plaintext" },
  keys = {
    {
      "<leader>jtt",
      function()
        require("markdown-table").create_table()
      end,
      mode = { "n" },
      desc = "Create a markdown table",
    },
    {
      "<leader>jtd",
      function()
        require("markdown-table").delete_column { to_reg = "+" }
      end,
      mode = { "n", "x" },
      desc = "Delete a markdown table column",
    },
    {
      "<leader>jtD",
      function()
        require("markdown-table").delete_column()
      end,
      mode = { "n", "x" },
      desc = "Delete a markdown table column without cutting",
    },
    {
      "<leader>jtA",
      function()
        require("markdown-table").paste_column { paste_mode = "before" }
      end,
      mode = { "n" },
      desc = "Add a markdown table column before",
    },
    {
      "<leader>jta",
      function()
        require("markdown-table").paste_column { paste_mode = "after" }
      end,
      mode = { "n" },
      desc = "Add a markdown table column after",
    },
    {
      "<leader>jtP",
      function()
        require("markdown-table").paste_column { paste_mode = "before", from_reg = "+" }
      end,
      mode = { "n" },
      desc = "Paste a markdown table column before",
    },
    {
      "<leader>jtp",
      function()
        require("markdown-table").paste_column { paste_mode = "after", from_reg = "+" }
      end,
      mode = { "n" },
      desc = "Paste a markdown table column after",
    },
  },
}
```

### nvim.pack:

```lua

vim.pack.add { "religiosa1/markdown-table.nvim" }
local MdTable = require("markdown-table")
MdTable.setup {
  -- your config opts here
}
vim.api.nvim_create_autocmd("FileType", {
  desc = "markdown-table bindings",
  pattern = { "markdown", "text", "plaintext" },
  callback = function(args)
    local buf_id = args.buf

    vim.keymap.set({ "n" }, "<leader>jtt", function()
      MdTable.create_table()
    end, {
      buf = buf_id,
      desc = "Create a markdown table",
    })

    vim.keymap.set({ "n", "x" }, "<leader>jtD", function()
      MdTable.delete_column()
    end, {
      buf = buf_id,
      desc = "Delete a markdown table column without cutting",
    })
    vim.keymap.set({ "n" }, "<leader>jtA", function()
      MdTable.paste_column { paste_mode = "before" }
    end, {
      buf = buf_id,
      desc = "Add a markdown table column before",
    })
    vim.keymap.set({ "n" }, "<leader>jta", function()
      MdTable.paste_column { paste_mode = "after" }
    end, {
      buf = buf_id,
      desc = "Add a markdown table column after",
    })
    vim.keymap.set({ "n" }, "<leader>jtP", function()
      MdTable.paste_column { paste_mode = "before", from_reg = "+" }
    end, {
      buf = buf_id,
      desc = "Paste a markdown table column before",
    })
    vim.keymap.set({ "n" }, "<leader>jtp", function()
      MdTable.paste_column { paste_mode = "after", from_reg = "+" }
    end, {
      desc = "Paste a markdown table column after",
    })
  end
)

```

## Configuration

```lua
-- TODO:
```

## License

markdown-table.nvim is MIT licensed.
