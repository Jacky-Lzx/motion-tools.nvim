local M = {}

local function empty_change(range, register)
  local registers = {}
  local names = { '"', "-", "1", register:lower() }
  if vim.o.clipboard:find("unnamedplus", 1, true) then
    names[#names + 1] = "+"
  end
  if vim.o.clipboard:match("unnamed%f[^%a]") then
    names[#names + 1] = "*"
  end
  for _, name in ipairs(names) do
    if name ~= "_" then
      registers[name] = vim.fn.getreginfo(name)
    end
  end
  -- Do not expose the synthetic character as deleted text in user registers.
  local hook = vim.api.nvim_create_autocmd("TextYankPost", {
    buffer = 0,
    once = true,
    callback = function()
      for name, info in pairs(registers) do
        if name ~= '"' then
          vim.fn.setreg(name, info)
        end
      end
      vim.fn.setreg('"', registers['"'])
    end,
  })
  vim.schedule(function()
    pcall(vim.api.nvim_del_autocmd, hook)
  end)
  require("motion_tools.range").select(range)
  local eventignore = vim.o.eventignore
  vim.o.eventignore = "all"
  local ok, err = pcall(vim.cmd.normal, { "\27i \27v", bang = true })
  vim.o.eventignore = eventignore
  if not ok then
    error(err)
  end
end

function M.select_motion(id, kind, direction, count, operator_pending, register)
  local opts = { direction = direction, count = count }
  if vim.fn.mode():match("^[vV\22]") then
    opts.reference = require("motion_tools.range").visual()
  end
  local ok, selected = pcall(function()
    local range = require("motion_tools.objects").find(id, kind, opts)
    if not range then
      return false
    end
    if vim.fn.getcmdwintype() == "" then
      vim.cmd.normal({ "\28\14", bang = true })
    end
    if require("motion_tools.range").equal(range.start, range.finish) then
      if not operator_pending or vim.v.operator ~= "c" then
        return false
      end
      -- Vim cannot represent a zero-width Visual motion. A temporary cell lets
      -- native change consume it while keeping this motion in the redo record.
      -- The placeholder and its removal share one undo block.
      empty_change(range, register or '"')
      return true
    end
    require("motion_tools.range").select(range)
    return true
  end)
  if not ok or not selected then
    vim.api.nvim_exec_autocmds("User", { pattern = "MotionToolsObjectCancelled", modeline = false })
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
    if not ok then
      vim.notify(selected, vim.log.levels.ERROR)
    end
  end
end

return M
