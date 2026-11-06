local M = {}

function M.jump(edge, opts)
  assert(edge == "start" or edge == "end", "motion-tools: invalid object boundary")
  opts = opts or {}
  local count = opts.count or vim.v.count1
  assert(type(count) == "number" and count >= 1 and count % 1 == 0, "motion-tools: invalid count")
  local id = opts.id
  if id == nil then
    local ok, value = pcall(vim.fn.getcharstr)
    if not ok then
      return false
    end
    id = value
  end
  if id == "\27" or id == "\3" then
    return false
  end
  local ok, range = pcall(require("motion_tools.objects").find, id, "around", { count = count })
  if not ok then
    vim.notify("motion-tools: " .. tostring(range), vim.log.levels.WARN)
    return false
  end
  if not range then
    return false
  end
  local pos = edge == "start" and range.start or range.finish
  -- Keep the provider's exclusive finish, including Neovim's normal EOL clamp.
  vim.cmd.normal({ "m'", bang = true })
  vim.api.nvim_win_set_cursor(0, { pos[1] + 1, pos[2] })
  return true
end

return M
