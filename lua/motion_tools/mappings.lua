local M = { owned = {} }

function M.setup(enabled)
  for _, item in ipairs(M.owned) do
    for _, current in ipairs(vim.api.nvim_get_keymap(item.mode)) do
      current.buf = nil
      if current.lhs == item.lhs and vim.deep_equal(current, item.installed) then
        pcall(vim.keymap.del, item.mode, item.lhs)
      end
    end
  end
  M.owned = {}
  if not enabled then
    return
  end
  local tools = require("motion_tools")
  local function map(modes, lhs, callback, desc, expr)
    for _, mode in ipairs(modes) do
      if vim.fn.maparg(lhs, mode) == "" then
        vim.keymap.set(
          mode,
          lhs,
          callback,
          { desc = "[Motion] " .. desc, silent = true, expr = expr }
        )
        local installed
        for _, current in ipairs(vim.api.nvim_get_keymap(mode)) do
          if current.callback == callback then
            current.buf = nil
            installed = current
            break
          end
        end
        M.owned[#M.owned + 1] = { mode = mode, lhs = installed.lhs, installed = installed }
      end
    end
  end
  map({ "n", "x", "o" }, "<leader>f", tools.jump, "Jump")
  map({ "n", "x", "o" }, "<leader>F", tools.treesitter, "Select syntax node")
  map({ "n", "x", "o" }, "<leader>j", tools.lines, "Jump to line")
  map({ "n", "x", "o" }, "<leader>k", tools.lines, "Jump to line")
  map({ "c" }, "<C-f>", tools.cmdline_jump, "Search labels", true)
  for _, key in ipairs({ "n", "N", "*", "#", "g*", "g#" }) do
    map({ "n" }, key, function()
      tools.search(key)
    end, "Search " .. key)
  end
  for target, suffix in pairs({
    buffer = "b",
    diagnostic = "d",
    quickfix = "q",
    location = "l",
    jump = "j",
    treesitter = "t",
  }) do
    for lhs, direction in pairs({
      ["[" .. suffix] = "prev",
      ["]" .. suffix] = "next",
      ["[" .. suffix:upper()] = "first",
      ["]" .. suffix:upper()] = "last",
    }) do
      local normal_only = target == "buffer"
        or target == "quickfix"
        or target == "location"
        or target == "jump"
      map(normal_only and { "n" } or { "n", "x", "o" }, lhs, function()
        tools.navigate(target, direction)
      end, direction .. " " .. target)
    end
  end
  for _, spec in ipairs({ { "i", "more" }, { "o", "less" } }) do
    for prefix, direction in pairs({ ["["] = "prev", ["]"] = "next" }) do
      map({ "n", "x", "o" }, prefix .. spec[1], function()
        tools.navigate("indent", direction, { change = spec[2] })
      end, direction .. " " .. spec[2] .. " indent")
    end
  end
end

return M
