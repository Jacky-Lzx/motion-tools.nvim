local M =
  { ns = vim.api.nvim_create_namespace("motion_tools.search"), generation = 0, buffers = {} }

function M.clear()
  M.generation = M.generation + 1
  for buf in pairs(M.buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
    end
  end
  M.buffers = {}
end

function M.show(pattern)
  local config = require("motion_tools.config").options.search
  M.clear()
  if
    not config.enabled
    or require("motion_tools.session").active
    or (pattern == nil and vim.v.hlsearch ~= 1)
  then
    return
  end
  pattern = pattern or vim.fn.getreg("/")
  if pattern == "" then
    return
  end
  local ok, count = pcall(
    vim.fn.searchcount,
    { pattern = pattern, recompute = 1, maxcount = config.max_count, timeout = config.timeout }
  )
  if not ok or not count.total or count.total == 0 or count.exact_match ~= 1 then
    return
  end
  local buf, cursor = vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)
  local total = tostring(count.total) .. (count.incomplete == 2 and "+" or "")
  local text = ("  [%s/%s%s]"):format(count.current, total, count.incomplete == 1 and " …" or "")
  vim.api.nvim_buf_set_extmark(
    buf,
    M.ns,
    cursor[1] - 1,
    0,
    { virt_text = { { text, "MotionToolsLens" } }, virt_text_pos = "eol", priority = 100 }
  )
  M.buffers[buf] = true
end

function M.refresh()
  M.generation = M.generation + 1
  local generation = M.generation
  vim.schedule(function()
    if generation ~= M.generation then
      return
    end
    local cmdtype = vim.fn.getcmdtype()
    -- Updating source extmarks during incsearch invalidates its current-match
    -- highlight. A floating cmdline/menu can flush that intermediate frame.
    if cmdtype == "" then
      M.show()
    end
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("MotionToolsSearch", { clear = true })
  M.clear()
  if not require("motion_tools.config").options.search.enabled then
    return
  end
  vim.api.nvim_create_autocmd(
    { "CursorMoved", "TextChanged", "BufEnter", "WinEnter", "CmdlineLeave" },
    { group = group, callback = M.refresh }
  )
  vim.api.nvim_create_autocmd(
    { "InsertEnter", "BufLeave", "WinLeave", "CmdlineEnter" },
    { group = group, callback = M.clear }
  )
  vim.api.nvim_create_autocmd(
    "OptionSet",
    { group = group, pattern = "hlsearch", callback = M.refresh }
  )
  -- :nohlsearch changes v:hlsearch without changing the option.
  vim.api.nvim_create_autocmd("SafeState", {
    group = group,
    callback = function()
      if vim.v.hlsearch == 0 then
        M.clear()
      end
    end,
  })
end

function M.dispose()
  M.clear()
  pcall(vim.api.nvim_del_augroup_by_name, "MotionToolsSearch")
end

return M
