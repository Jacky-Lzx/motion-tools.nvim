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
| `<leader>f` | Normal, Visual, operator | Type a literal query, then a displayed jump label |
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
| `g[` / `g]` + object key | Normal | Object start / exclusive end |

Uppercase bracket suffixes select the first/last target. Counts work for search
and bracket navigation. Indentation and syntax boundaries stop at their edges.
Neovim's own mappings also count as existing mappings; bind the API explicitly
when you want to replace them.

During literal search, single-letter jump labels appear after matches as you
type. Press a displayed label to jump directly, or keep typing to narrow the
search. Letters that could continue the query are excluded from live labels,
respecting search case options. Surviving matches keep their labels when possible.
If there are too few safe letters, nearby targets receive labels first; continue
typing or press Enter/Tab to label all collected targets.

Enter/Tab switches to full label selection, or jumps directly for a unique match.
Full labels have equal length, expanding to two or more letters for larger result
sets. Backspace edits the query or label prefix; from full label mode it returns
to the query. Ctrl-U clears the query. Escape/Ctrl-C cancels.
Set `live_labels = false` to use only the Enter/Tab workflow. Regex and syntax
searches use that workflow regardless of this option.

Line jumps (`<leader>j` / `<leader>k`) use the configured letters followed by
their missing opposite-case counterparts. The default alphabet provides 52
distinct single-letter labels; type each label with the displayed case.

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
  live_labels = true,
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

## Text-object API

```lua
motion.setup({
  mappings = false,
  textobjects = {
    search = { lines = 500, max_bytes = 1024 * 1024 },
    objects = {
      z = function(ctx)
        return { { start = { ctx.pos[1], 0 }, finish = { ctx.pos[1], 1 } } }
      end,
      t = false,
    },
    treesitter = { f = { inside = "function.inner", around = "function.outer" } },
  },
})
vim.keymap.set({ "o", "x" }, "i", "<Plug>(MotionTools-inside)")
vim.keymap.set({ "o", "x" }, "a", "<Plug>(MotionTools-around)")
vim.keymap.set("n", "g[", "<Plug>(MotionTools-goto_start)")
vim.keymap.set("n", "g]", "<Plug>(MotionTools-goto_end)")
```

Setup always registers `<Plug>(MotionTools-<action>)` endpoints for `inside`,
`around`, their `_next` / `_prev` variants, and `goto_start` / `goto_end`, without
assigning user keys. Set `mappings = true` for the conventional layout, or use
explicit `textobjects.mappings = { inside = "i" }` entries. Existing mappings
remain user-owned. `dispose()` removes only unchanged plugin-owned endpoints.

`find_object(id, "inside"|"around", opts)` returns a range or `nil`. Options are
zero-based `pos`, `buf`, `count`, `direction` (`current`, `next`, `prev`), and a
`reference` range for Visual expansion. `select_object(id, kind, opts)` selects
that range in the current window. `object_boundary("start"|"end", opts)` reads
an object key or accepts `opts.id`, using `opts.count` or `vim.v.count1`. It moves
to the around-range boundary and records the previous context mark; exclusive
ends retain Neovim's usual EOL clamp. Esc/Ctrl-C and missing objects do not move.

Ranges use zero-based rows and UTF-8 byte columns, with an exclusive finish:
`{ start = { row, byte }, finish = { row, byte }, mode = "char"|"line" }`.
`motion_tools.range` owns validation, coordinate comparison, native Visual range
capture and range selection. Buffer modification belongs to editing-tools.nvim.

Custom providers receive `{ id, kind, buf, pos, first, last }`; `first`/`last`
are the search window, with exclusive `last`. Return a list of valid ranges or
`{}` without editing the buffer. Startup and ordinary Insert mode do not load
object scanning, text-object selection or query code. Every action loads its
own implementation on demand, without loading editing-tools.nvim.
`User MotionToolsObjectCancelled` lets editing integrations cancel their pending
operator state when an object cannot be selected.

## Text objects

Text objects work with native operators and Visual mode. Use `i` / `a` for inside /
around, `in` / `an` for the next object, and `il` / `al` for the previous object.
Counts choose enclosing objects from smallest to largest, or the nth next/previous
object. Native `w`, `W`, `s`, and `p` objects pass through to Vim.

| Key | Object |
| --- | --- |
| `b`, `(`, `)`, `[`, `]`, `{`, `}` | Balanced brackets; inner whitespace trimmed |
| `q`, `"`, `'`, backtick | Ordinary quoted strings |
| `a` | Comma-separated argument; nested brackets and strings protected |
| `u`, `U` | Function call, with / without member chain in the name |
| `d`, `e`, `_`, space | Digits, subword, underscore segment, whitespace |
| `t`, `<`, `>` | Matching tags, angle brackets |
| `i`, `g` | Indentation block, entire buffer (linewise) |
| `f`, `c`, `o` | Tree-sitter function, class, block/conditional/loop |

Whitespace-only bracket interiors remain selectable. Empty objects can be changed
with `c`, including dot-repeat; other operators cancel on a zero-width object.

`g[` / `g]` followed by an object key move to its start / exclusive end.
Tree-sitter parsers are optional. Queries ship for Lua, Python, JavaScript,
TypeScript, TSX, Bash, Fish, C/C++/CUDA, CMake, Rust, Swift, Java,
SystemVerilog, GDScript, MATLAB, Nix, HTML, CSS, JSON, YAML, TOML,
Markdown, LaTeX, BibTeX and Vue. Other languages can supply
`queries/<lang>/textobjects.scm`. Injected languages use their own queries.
Query data inherited from nvim-treesitter-textobjects is pinned and attributed in
`THIRD_PARTY.md`; its Lua plugin is not required. Parsers remain externally managed.

Lexical and indentation objects scan at most 500 lines on each side and 1 MiB by
default. Tree-sitter uses the installed parser and searches captures within the
configured line window. Bracket/quote,
argument, call, and tag objects use lexical rules, not language grammars. They do
not parse comments, raw strings, language-specific literals, HTML void elements,
or quoted `>` characters in attributes. Use Tree-sitter providers when those
distinctions matter.

`:MotionTools` defaults to `jump`; `lines`, `treesitter`, `treesitter_search`,
`lens`, and `navigate {target} {next|prev|first|last}` are also available.
See `:help motion-tools` for range semantics, options, and scope.

## Validation

Run `sh tests/run.sh` (Neovim, Python 3, StyLua). Set
`MOTION_TOOLS_PARSER_DIR` to a runtime directory containing `parser/lua.so` for
real Tree-sitter text-object fixtures. The broader query contract suite runs as
`MOTION_TOOLS_PARSER_ROOT=/path/to/runtime sh tests/run.sh parsers`; build its
pinned fixtures with `sh tests/install-parsers.sh /path/to/runtime`. The suite exercises actual PTY input for jumps,
operators, registers, Visual modes, Unicode, windows, search and cancellation.
`MOTION_TOOLS_NVIM_INIT=/path/to/init.lua python3 tests/tui.py` runs the same
workflows in a configured session with temporary mappings and isolated test state.

## Command ownership

Commands belong to the plugin; choose global entry keys and short aliases in
your configuration. Registration reports same-name conflicts without replacing
user commands. Reconfiguration refreshes only commands still owned by this
plugin, and cleanup preserves subsequent user replacements.

## Setup contract

`setup(nil)` uses defaults. Configuration must be a table; caller-owned tables
are copied before use. Invalid configuration types do not replace live handlers
or commands. Repeating setup must not accumulate automatic registrations.

`setup(opts)` validates fresh default-based options before updating search and
mappings. `dispose()` cancels an active jump without moving or editing source,
releases search/redo observers and unchanged owned mappings, and resets options.
It is repeatable; later setup or an explicit jump can establish its needed
observers again. User mapping replacements remain untouched.

## Health and inspection

Health reports actionable failures and a compact result for applicable checks. Disabled,
optional and not-yet-activated features do not warn solely because they are inactive.
Inspection does not configure plugins, start services or install dependencies.

[Test workflow](tests/README.md): registered suites, filtering, required fixtures and retained failure evidence.
