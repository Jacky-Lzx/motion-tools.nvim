if vim.g.loaded_motion_tools then
  return
end
vim.g.loaded_motion_tools = true
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    require("motion_tools.view").highlights()
  end,
})
require("motion_tools.user_command").create("MotionTools", function(opts)
  local tools = require("motion_tools")
  local action = opts.fargs[1] or "jump"
  if action == "jump" or action == "lines" or action == "treesitter" or action == "lens" then
    tools[action]()
  elseif action == "treesitter_search" then
    tools.treesitter({ search = true })
  elseif action == "navigate" then
    tools.navigate(opts.fargs[2], opts.fargs[3])
  else
    vim.notify("motion-tools: unknown action " .. action, vim.log.levels.WARN)
  end
end, {
  nargs = "*",
  complete = function()
    return { "jump", "lines", "treesitter", "treesitter_search", "lens", "navigate" }
  end,
  desc = "Search and navigate the editing area",
})
