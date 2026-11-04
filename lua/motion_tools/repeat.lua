local M = { last = {}, reading = false, repeating = false }
local ns = vim.api.nvim_create_namespace("motion_tools.repeat")

-- Observe native redo without mapping '.', taking over operatorfunc, or changing
-- register/count handling. The replayed Lua motion runs before the next tick.
vim.on_key(function(char)
  if char == "." and not M.reading and vim.fn.mode() == "n" then
    M.repeating = true
    vim.schedule(function()
      M.repeating = false
    end)
  end
end, ns)

return M
