vim.opt.runtimepath:prepend(vim.fn.getcwd())
local tools = require("motion_tools")
local Match = require("motion_tools.match")
local Nav = require("motion_tools.navigate")
local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local function lines(value)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, value)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end
local function collect(query, opts)
  return Match.collect({ win }, query, opts)
end

tools.setup()
check(vim.fn.maparg("<leader>f", "n") == "", "default setup binds keys")
check(not pcall(tools.setup, { labels = "aaa" }), "duplicate labels accepted")
check(not pcall(tools.setup, { max_matches = 0 }), "zero match limit accepted")
check(not pcall(tools.setup, { search = { enabled = 2 } }), "invalid search config accepted")
lines({ "abc abc", "  ABC", "", "中文中文", "back\\slash" })
vim.o.ignorecase, vim.o.smartcase = true, true
check(#collect("abc") == 3, "ignorecase")
check(#collect("ABC") == 1, "smartcase")
check(#collect("back\\slash") == 1, "literal backslash")
check(#collect("中") == 2, "UTF-8 matching")
local chinese = collect("中")
check(chinese[1].end_col - chinese[1].col == 3, "UTF-8 byte ranges")
check(#collect("^", { regex = true }) == 5, "^ repeated at offsets")
check(#collect("$", { regex = true }) == 5, "zero-width end")
check(#collect("\\<abc", { regex = true }) == 3, "word boundaries")
check(#collect("\\(", { regex = true }) == 0, "invalid regex")
check(#collect("", { lines = true }) == 4, "blank line target")
local limited, warning = collect("a", { max_matches = 1 })
check(#limited == 1 and warning ~= nil, "match cap")
local many = {}
for i = 1, 40 do
  many[i] = {}
end
Match.labels(many, "ab")
local seen = {}
for _, item in ipairs(many) do
  check(#item.label == 6 and not seen[item.label], "prefix-free labels")
  seen[item.label] = true
end
check(vim.deep_equal(Match.end_pos(Match.range(win, 3, 0, 3, 6)), { 4, 3 }), "UTF-8 inclusive end")
check(
  vim.deep_equal(Match.end_pos(Match.range(win, 0, 0, 1, 0)), { 1, 7 }),
  "multiline end at column zero"
)

local keys = { 1, 3, 6 }
check(Nav.index(keys, 3, "next", 2, true) == 1, "count wrapping")
check(Nav.index(keys, 1, "prev", 1, false) == 1, "no wrap")
check(Nav.index(keys, 0, "first", 2, true) == 3, "first count")
check(Nav.index(keys, 0, "last", 2, true) == 3, "last count")
check(Nav.index({}, 0, "next", 1, true) == nil, "empty target")
lines({ "root", "  child", "    grandchild", "  sibling", "tail" })
check(tools.navigate("indent", "next", { change = "more", count = 2 }), "indent count")
check(vim.fn.line(".") == 3, "indent hierarchy")
tools.navigate("indent", "next", { change = "less", count = 2 })
check(vim.fn.line(".") == 5, "indent less")
vim.fn.setqflist({
  { bufnr = buf, lnum = 2, col = 1 },
  { text = "invalid", valid = 0 },
  { bufnr = buf, lnum = 4, col = 1 },
})
check(tools.navigate("quickfix", "first"), "quickfix first")
tools.navigate("quickfix", "next")
check(vim.fn.line(".") == 4 and vim.fn.getqflist({ idx = 0 }).idx == 3, "invalid quickfix entries")
tools.navigate("quickfix", "next")
check(vim.fn.line(".") == 2, "quickfix wrapping")
vim.fn.setloclist(0, { { bufnr = buf, lnum = 5 } })
check(tools.navigate("location", "first") and vim.fn.line(".") == 5, "window location list")
local ns = vim.api.nvim_create_namespace("motion-test")
vim.diagnostic.set(ns, buf, {
  { lnum = 1, col = 2, message = "one", severity = 1 },
  { lnum = 3, col = 2, message = "two", severity = 2 },
})
tools.navigate("diagnostic", "first")
check(vim.fn.line(".") == 2, "diagnostic first")
tools.navigate("diagnostic", "next", { severity = vim.diagnostic.severity.WARN })
check(vim.fn.line(".") == 4, "diagnostic severity")

local existing = function() end
vim.keymap.set("n", "<leader>f", existing)
tools.setup({ mappings = true })
check(
  vim.fn.maparg("<leader>f", "n", false, true).callback == existing,
  "existing mapping overwritten"
)
check(vim.fn.maparg("<leader>j", "n", false, true).callback ~= nil, "optional mappings missing")
vim.keymap.set("n", "<leader>j", existing)
tools.setup({ mappings = false })
check(
  vim.fn.maparg("<leader>j", "n", false, true).callback == existing,
  "replacement mapping removed"
)
check(vim.fn.maparg("<leader>k", "n") == "", "owned mapping leaked")

vim.o.hlsearch = true
vim.fn.setreg("/", "child")
vim.v.hlsearch = 1
tools.lens()
check(
  #vim.api.nvim_buf_get_extmarks(buf, require("motion_tools.search").ns, 0, -1, {}) == 1,
  "lens missing"
)
vim.v.hlsearch = 0
tools.lens()
check(
  #vim.api.nvim_buf_get_extmarks(buf, require("motion_tools.search").ns, 0, -1, {}) == 0,
  "nohlsearch lens leaked"
)
vim.bo.filetype = "motion_no_parser"
check(#require("motion_tools.treesitter").ancestors(win) == 0, "missing parser")

local parser_dir = vim.env.MOTION_TOOLS_PARSER_DIR
if parser_dir then
  vim.opt.runtimepath:append(parser_dir)
  lines({ "local word = '中文'", "print(word)" })
  vim.bo.filetype = "lua"
  vim.api.nvim_win_set_cursor(win, { 1, 7 })
  local nodes = require("motion_tools.treesitter").ancestors(win)
  check(#nodes >= 3 and nodes[1].kind == "identifier", "real Tree-sitter ancestors")
  local results = require("motion_tools.treesitter").search({ win }, "word", { max_matches = 10 })
  check(#results == 2 and results[1].kind == "identifier", "Tree-sitter search")
end
print("PASS " .. checks .. " matching, navigation, ownership, search and parser checks")
vim.cmd("qa!")
