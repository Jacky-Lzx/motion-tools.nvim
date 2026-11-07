vim.opt.rtp:prepend(vim.fn.getcwd())
local H = require("tests.object_helpers")
local E = require("motion_tools")
dofile("tests/object_helpers.lua").setup()
H.buffer({ 'foo({a, (b, c)}, "x,y", z)' }, { 1, 9 })
H.eq(H.text("b"), "b, c", "smallest enclosing bracket")
H.eq(H.text("b", "inside", { count = 2 }), "a, (b, c)", "nested count")
H.eq(H.text("b", "inside", { count = 3 }), '{a, (b, c)}, "x,y", z')
H.eq(H.text("a"), "b")
H.buffer({ 'foo(a, nested(b,c), "x,y", z)' }, { 1, 8 })
H.eq(H.text("a"), "nested(b,c)")
H.eq(H.text("a", "around"), " nested(b,c), ")
H.eq(H.text("u", "around"), "nested(b,c)")
H.buffer({ 'hello "你好吗" (x)' }, { 1, 9 })
H.eq(H.text("q"), "你好吗")
H.keys("diq")
H.eq(H.lines(), { 'hello "" (x)' }, "operator text object")
H.keys("u")
H.eq(H.lines(), { 'hello "你好吗" (x)' }, "UTF-8 undo")
H.buffer({ "(a (b) c)" }, { 1, 4 })
H.keys("d2ib")
H.eq(H.lines(), { "()" }, "count with operator")
H.buffer({ "camelHTTPServer snake_case 123" })
H.eq(H.text("e"), "camel")
H.eq(H.text("e", "inside", { direction = "next", count = 2 }), "Server")
H.eq(H.text("d"), "123")
H.keys("diw")
H.eq(H.lines(), { " snake_case 123" }, "native word fallback")
H.buffer({ "<div><b>你好</b></div>" }, { 1, 10 })
H.eq(H.text("t"), "你好")
H.eq(H.text("t", "around", { count = 2 }), "<div><b>你好</b></div>")
H.buffer({ "(a) (b) (c)" }, { 1, 5 })
H.eq(H.text("b", "inside", { direction = "next" }), "c")
H.eq(H.text("b", "inside", { direction = "prev" }), "a")
H.buffer({ "x (a)" })
H.keys("dib")
H.eq(H.lines(), { "x ()" }, "forward lookup")
H.buffer({ "nothing" })
H.keys("dib")
H.eq(H.lines(), { "nothing" }, "missing object cancels")
H.eq(vim.fn.mode(), "n")
H.buffer({ "(one (two) three)" }, { 1, 7 })
H.keys("vibibd")
H.eq(H.lines(), { "()" }, "visual expansion")
H.buffer({ "first", "  a", "  b", "last" }, { 2, 2 })
H.eq(H.text("i"), "  a\n  b")
H.eq(H.text("g"), "first\n  a\n  b\nlast")
H.buffer({ "(a) (b)" }, { 1, 1 })
H.keys("cibX<Esc>j")
H.eq(H.lines(), { "(X) (b)" }, "change object")
H.keys("$h.")
H.eq(H.lines(), { "(X) (X)" }, "native change repeat")

dofile("tests/object_helpers.lua").setup({
  objects = {
    z = function(ctx)
      return { { start = { ctx.pos[1], 0 }, finish = { ctx.pos[1], 1 } } }
    end,
  },
})
H.buffer({ "abc" })
H.keys("diz")
H.eq(H.lines(), { "bc" }, "custom provider")
dofile("tests/object_helpers.lua").setup({ mappings = { inside = false } })
H.eq(vim.fn.maparg("i", "o"), "", "setup removes previous mappings")
dofile("tests/object_helpers.lua").setup()

vim.opt.runtimepath:append(
  vim.env.MOTION_TOOLS_PARSER_ROOT
    or vim.env.EDITING_TOOLS_PARSER_DIR
    or vim.fn.expand("~/.local/share/nvim/site")
)
H.buffer(
  { "local function f(x)", "  return x + 1", "end", "", "local g = function() return 2 end" },
  { 2, 3 }
)
vim.bo.filetype = "lua"
H.eq(H.text("f"), "return x + 1", "Lua parser query")
H.eq(H.text("f", "around"), "local function f(x)\n  return x + 1\nend")
H.keys("dif")
H.eq(H.lines()[2], "  ", "Tree-sitter operator")
vim.treesitter.query.set(
  "lua",
  "textobjects",
  [[
  (function_declaration body: (block (_)+ @function.inner)) @function.outer
]]
)
H.buffer({
  "function f()",
  "  local a = 1",
  "  local b = 2",
  "  return a + b",
  "end",
  "function g()",
  "  return 3",
  "end",
}, { 3, 3 })
vim.bo.filetype = "lua"
H.eq(
  H.text("f"),
  "local a = 1\n  local b = 2\n  return a + b",
  "quantified capture spans the whole function body"
)
H.eq(
  H.text("f", "inside", { direction = "next" }),
  "return 3",
  "separate query matches stay separate"
)
H.keys("dif")
H.eq(
  H.lines(),
  { "function f()", "  ", "end", "function g()", "  return 3", "end" },
  "quantified capture deletion"
)
vim.treesitter.query.set("lua", "textobjects", nil)
H.buffer(
  { "class C:", "    def f(self):", "        return 1", "", "def g():", "    pass" },
  { 3, 8 }
)
vim.bo.filetype = "python"
H.eq(H.text("f"), "return 1", "Python function")
H.eq(H.text("c", "around"), "class C:\n    def f(self):\n        return 1", "Python class")
H.buffer({ "local x = 1" })
vim.bo.filetype = "not_a_language"
H.eq(H.text("f"), nil, "missing parser")
H.buffer({ "() ()" }, { 1, 1 })
H.keys("ci(X<Esc>$h.")
H.eq(H.lines(), { "(X) (X)" }, "repeat empty native change")
for _, delimiters in ipairs({ "[]", "{}", "(  )", "[  ]", "{  }" }) do
  H.buffer({ delimiters }, { 1, 1 })
  H.keys("cibX<Esc>")
  H.eq(
    H.lines(),
    { delimiters:sub(1, 1) .. "X" .. delimiters:sub(-1) },
    "generic empty bracket change"
  )
end
H.buffer({ '""' }, { 1, 0 })
H.keys("ciqX<Esc>")
H.eq(H.lines(), { '"X"' }, "generic empty quote change")
H.buffer({ "(a) () ()" }, { 1, 1 })
H.keys("cibX<Esc>")
vim.api.nvim_win_set_cursor(0, { 1, 5 })
H.keys(".")
H.eq(H.lines(), { "(X) (X) ()" }, "repeat nonempty change into empty object")
vim.api.nvim_win_set_cursor(0, { 1, 9 })
H.keys(".")
H.eq(H.lines(), { "(X) (X) (X)" }, "retain change motion after empty repeat")
H.buffer({ "()" }, { 1, 1 })
vim.fn.setreg("a", "named")
vim.fn.setreg("-", "small")
vim.fn.setreg("1", "numbered")
vim.fn.setreg('"', "unnamed")
local registers = {}
for _, name in ipairs({ "a", "-", "1", '"' }) do
  registers[name] = vim.fn.getreginfo(name)
end
H.keys('"acibX<Esc>')
H.eq(H.lines(), { "(X)" })
for name, info in pairs(registers) do
  H.eq(vim.fn.getreginfo(name), info, "empty change preserves " .. name)
end
H.keys("u")
H.eq(H.lines(), { "()" }, "empty change undoes in one step")
H.keys("<C-r>")
H.eq(H.lines(), { "(X)" }, "empty change redo has no placeholder")

print("textobjects: " .. H.count .. " assertions passed")
