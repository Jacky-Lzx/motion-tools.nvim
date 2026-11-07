local M = {}

function M.check()
  vim.health.start("motion-tools.nvim")
  if vim.fn.has("nvim-0.11") == 0 then
    vim.health.error("Neovim 0.11+ is required", { "Upgrade Neovim" })
  else
    vim.health.ok("Motion runtime requirements are satisfied; optional parsers are checked on use.")
  end
end

return M
