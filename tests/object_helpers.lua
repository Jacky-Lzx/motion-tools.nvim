local M = { count = 0 }
M.mappings = {
  inside = "i",
  around = "a",
  inside_next = "in",
  around_next = "an",
  inside_prev = "il",
  around_prev = "al",
  goto_start = "g[",
  goto_end = "g]",
}
function M.setup(opts)
  require("motion_tools").setup({
    textobjects = vim.tbl_deep_extend("force", { mappings = M.mappings }, opts or {}),
  })
end
function M.eq(actual, expected, message)
  M.count = M.count + 1
  assert(
    vim.deep_equal(actual, expected),
    (message or "assertion")
      .. "\nexpected: "
      .. vim.inspect(expected)
      .. "\nactual: "
      .. vim.inspect(actual)
  )
end
function M.buffer(lines, cursor)
  vim.cmd.enew({ bang = true })
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
  vim.api.nvim_win_set_cursor(0, cursor or { 1, 0 })
  -- Separate fixture creation from edits performed by real input.
  vim.cmd("let &undolevels = &undolevels")
end
function M.keys(keys)
  vim.api.nvim_feedkeys(vim.keycode(keys), "xt", false)
end
function M.lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, true)
end
function M.text(id, kind, opts)
  local range = require("motion_tools").find_object(id, kind or "inside", opts)
  if not range then
    return nil
  end
  local lines = range.mode == "line"
      and vim.api.nvim_buf_get_lines(0, range.start[1], range.finish[1] + 1, true)
    or vim.api.nvim_buf_get_text(
      0,
      range.start[1],
      range.start[2],
      range.finish[1],
      range.finish[2],
      {}
    )
  return table.concat(lines, "\n")
end
return M
