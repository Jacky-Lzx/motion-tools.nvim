# motion-tools.nvim

Search and navigate the current editing scene: labeled jumps, line jumps,
Tree-sitter selections, native search feedback, and bracket navigation.
No third-party dependencies. Requires Neovim 0.11+; syntax features need a parser
for the buffer's filetype.

## Setup

```lua
{
  dir = vim.fn.expand("~/Documents/Github/nvim_plugins/motion-tools.nvim"),
  name = "motion-tools.nvim",
  main = "motion_tools",
  opts = { mappings = true },
}
```

`setup()` installs search feedback but binds no keys by default. Set
`mappings = true` for the optional bindings below. Existing mappings are preserved.
Reconfiguration removes only bindings still owned by this plugin.

| Binding | Modes | Action |
| --- | --- | --- |
| `<leader>f` | Normal, Visual, operator | Type a literal query, Enter/Tab, then a label |
| `<leader>F` | Normal, Visual, operator | Choose an ancestor syntax node |
| `<leader>j`, `<leader>k` | Normal, Visual, operator | Label nonblank line starts |
| `<C-f>` in `/` or `?` | Command line | Choose a label for the current search pattern |
| `n`, `N`, `*`, `#`, `g*`, `g#` | Normal | Native search with a match counter |
| `[b` / `]b` | Normal | Previous/next listed buffer |
| `[d` / `]d` | Normal, Visual, operator | Previous/next diagnostic |
| `[q` / `]q`, `[l` / `]l` | Normal | Quickfix / window location list |
| `[j` / `]j` | Normal | Native jumplist |
| `[t` / `]t` | Normal, Visual, operator | Syntax node starts/ends |
| `[i` / `]i`, `[o` / `]o` | Normal, Visual, operator | More/less indentation |

Uppercase bracket suffixes select the first/last target. Counts work for search
and bracket navigation. Indentation and syntax boundaries stop at their edges.
Neovim's own mappings also count as existing mappings; bind the API explicitly
when you want to replace them.

During a jump, Backspace edits the query or label prefix; from label mode it
returns to the query. Ctrl-U clears the query. Escape/Ctrl-C cancels. A unique
query match jumps immediately on Enter/Tab. Labels have equal length, expanding
to two or more letters for larger result sets.

Normal jumps can cross ordinary windows in the current tab. Visual and operator
jumps stay in the source window. Successful jumps enter the jumplist; cancellation
restores views without changing text or search history. Ordinary jumps leave `/`
untouched. Command-line label jumps commit the search only after selection.
Operator `.` repeats the prior query and candidate ordinal without reopening the
prompt. It resolves fresh matches at the new cursor location.

## API

```lua
local motion = require("motion_tools")
motion.setup({
  labels = "asdfghjklqwertyuiopzxcvbnm",
  multi_window = true,
  max_matches = 1000,
  mappings = false,
  search = { enabled = true, timeout = 100, max_count = 9999, center = true },
})

vim.keymap.set({ "n", "x", "o" }, "<leader>f", motion.jump)
vim.keymap.set({ "n", "x", "o" }, "<leader>F", motion.treesitter)
vim.keymap.set({ "n", "x", "o" }, "<leader>j", motion.lines)
vim.keymap.set({ "o", "x" }, "<leader>m", function()
  motion.treesitter({ search = true }) -- Search text, select its smallest named node
end)
vim.keymap.set("c", "<C-f>", motion.cmdline_jump, { expr = true })

motion.jump({ pattern = "TODO", regex = false }) -- Immediately show labels
motion.jump({ pattern = [[\<error\>]], regex = true })
motion.navigate("diagnostic", "next", { count = 2, wrap = false })
motion.navigate("indent", "prev", { change = "less" })
motion.lens() -- Refresh native search counter explicitly
```

`:MotionTools` defaults to `jump`; `lines`, `treesitter`, `treesitter_search`,
`lens`, and `navigate {target} {next|prev|first|last}` are also available.
See `:help motion-tools` for range semantics, options, and scope.

## Validation

Run `sh tests/run.sh` (Neovim, Python 3, StyLua). Set
`MOTION_TOOLS_PARSER_DIR` to a runtime directory containing `parser/lua.so` to
include real Tree-sitter tests. The suite exercises actual PTY input for jumps,
operators, registers, Visual modes, Unicode, windows, search and cancellation.
`MOTION_TOOLS_NVIM_INIT=/path/to/init.lua python3 tests/tui.py` runs the same
workflows in a configured session with temporary mappings and isolated test state.
