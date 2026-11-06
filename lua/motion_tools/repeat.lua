local M = { last = {}, reading = false, repeating = false }
local ns = vim.api.nvim_create_namespace("motion_tools.repeat")

-- Observe native redo without mapping '.', taking over operatorfunc, or changing
-- register/count handling. The replayed Lua motion runs before the next tick.
local attached, generation = false, 0
function M.setup()
  if attached then
    return
  end
  attached = true
  generation = generation + 1
  local version = generation
  vim.on_key(function(char)
    if char == "." and not M.reading and vim.fn.mode() == "n" then
      M.repeating = true
      vim.schedule(function()
        if generation == version then
          M.repeating = false
        end
      end)
    end
  end, ns)
end

function M.dispose()
  generation = generation + 1
  vim.on_key(nil, ns)
  attached = false
  M.last, M.reading, M.repeating = {}, false, false
end

M.setup()

return M
