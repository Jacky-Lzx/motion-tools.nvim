vim.opt.rtp:prepend(vim.fn.getcwd())
local tools = require("motion_tools")
tools.setup()
for _, name in ipairs({ "object", "objects", "textobjects", "range", "scan", "object_treesitter" }) do
  assert(not package.loaded["motion_tools." .. name], name .. " loaded at startup")
end
vim.api.nvim_feedkeys(vim.keycode("itext<Esc>"), "xt", false)
assert(not package.loaded["motion_tools.objects"])
assert(not pcall(tools.setup, { textobjects = { search = { max_bytes = 0 } } }))
assert(not tools.object_boundary("start", { id = "\27" }))
assert(not tools.object_boundary("end", { id = "\3" }))
assert(not package.loaded["motion_tools.objects"], "cancellation must not initialize scanning")
local source = { "xx ((中)) tail" }
vim.api.nvim_buf_set_lines(0, 0, -1, false, source)
tools.setup({ mappings = true })
for _, case in ipairs({ { "g[b", 4 }, { "2g[b", 3 }, { "g]b", 9 }, { "2g]b", 10 } }) do
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  vim.api.nvim_feedkeys(case[1], "xt", false)
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, case[2] }), case[1])
  assert(vim.fn.getpos("''")[3] == 6)
end
local cursor, mark = vim.api.nvim_win_get_cursor(0), vim.fn.getpos("''")
assert(not tools.object_boundary("start", { id = "z" }))
assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), cursor))
assert(vim.deep_equal(vim.fn.getpos("''"), mark))
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), source))
assert(not package.loaded.editing_tools, "motion must be independent of editing")
local opts = {
  textobjects = {
    objects = {
      z = function(ctx)
        return { { start = { 0, 0 }, finish = { 0, ctx.pos[2] + 1 }, mode = "char" } }
      end,
    },
  },
}
tools.setup(opts)
opts.textobjects.objects.z = false
assert(tools.find_object("z", "around"))
assert(not package.loaded.editing_tools)
assert(vim.fn.maparg("g[", "n") == "")
tools.dispose()
assert(vim.fn.maparg("<Plug>(MotionTools-inside)", "o") == "")
print(
  "Object boundaries: cold setup/Insert, counts, UTF-8, context marks, custom objects and isolation passed"
)
