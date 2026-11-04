local M = { ns = vim.api.nvim_create_namespace("motion_tools"), windows = {} }

function M.highlights()
  for name, link in pairs({
    Match = "Search",
    Label = "IncSearch",
    Current = "CurSearch",
    Lens = "Comment",
  }) do
    vim.api.nvim_set_hl(0, "MotionTools" .. name, { default = true, link = link })
  end
end

function M.clear()
  M.windows = {}
  for _, field in ipairs({ "panel_win", "prompt_win" }) do
    if M[field] and vim.api.nvim_win_is_valid(M[field]) then
      vim.api.nvim_win_close(M[field], true)
    end
    M[field] = nil
  end
  vim.cmd("redraw!")
end

function M.prompt(text)
  if not M.prompt_buf or not vim.api.nvim_buf_is_valid(M.prompt_buf) then
    M.prompt_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M.prompt_buf].bufhidden = "wipe"
  end
  vim.api.nvim_buf_set_lines(M.prompt_buf, 0, -1, false, { text })
  local config = {
    relative = "editor",
    row = math.max(0, vim.o.lines - vim.o.cmdheight - 2),
    col = 0,
    width = math.max(1, math.min(vim.o.columns, vim.fn.strdisplaywidth(text))),
    height = 1,
    style = "minimal",
    border = "none",
    focusable = false,
    zindex = 80,
  }
  if M.prompt_win and vim.api.nvim_win_is_valid(M.prompt_win) then
    vim.api.nvim_win_set_config(M.prompt_win, config)
  else
    M.prompt_win = vim.api.nvim_open_win(M.prompt_buf, false, config)
    vim.wo[M.prompt_win].wrap = false
    vim.wo[M.prompt_win].winhighlight = "Normal:Question"
  end
  vim.cmd("redraw!")
end

function M.panel(matches, prefix)
  local lines = {}
  for _, match in ipairs(matches) do
    if match.label:sub(1, #prefix) == prefix then
      lines[#lines + 1] = ("%s  %s  %d:%d–%d:%d"):format(
        match.label:sub(#prefix + 1),
        match.kind or "node",
        match.row + 1,
        match.col + 1,
        match.end_row + 1,
        match.end_col
      )
    end
  end
  if not M.panel_buf or not vim.api.nvim_buf_is_valid(M.panel_buf) then
    M.panel_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M.panel_buf].bufhidden = "wipe"
  end
  vim.api.nvim_buf_set_lines(M.panel_buf, 0, -1, false, lines)
  if not M.panel_win or not vim.api.nvim_win_is_valid(M.panel_win) then
    local width = 1
    for _, line in ipairs(lines) do
      width = math.max(width, vim.fn.strdisplaywidth(line))
    end
    M.panel_win = vim.api.nvim_open_win(M.panel_buf, false, {
      relative = "editor",
      row = 1,
      col = math.max(0, vim.o.columns - width - 4),
      width = math.max(1, math.min(width, vim.o.columns - 4)),
      height = math.max(1, math.min(#lines, vim.o.lines - 6)),
      style = "minimal",
      border = "rounded",
      focusable = false,
      zindex = 70,
    })
    vim.wo[M.panel_win].wrap = false
  end
end

function M.show(matches, prefix, labels, live)
  M.windows = {}
  for _, match in ipairs(matches) do
    if not labels or match.label:sub(1, #prefix) == prefix then
      local rows = M.windows[match.win] or {}
      M.windows[match.win] = rows
      local marks = rows[match.row] or {}
      rows[match.row] = marks
      marks[#marks + 1] = {
        match = match,
        label = live and match.live_label or labels and match.label:sub(#prefix + 1) or nil,
        after = live,
      }
    end
  end
  vim.cmd("redraw!")
end

M.highlights()
vim.api.nvim_set_decoration_provider(M.ns, {
  on_win = function(_, win)
    return M.windows[win] ~= nil
  end,
  on_line = function(_, win, buf, row)
    for _, item in ipairs((M.windows[win] or {})[row] or {}) do
      local match = item.match
      local opts = { ephemeral = true, priority = 200 }
      if match.end_row > row or match.end_col > match.col then
        opts.end_row, opts.end_col = match.end_row, match.end_col
        opts.hl_group = "MotionToolsMatch"
      end
      if item.label and item.label ~= "" then
        if item.after then
          vim.api.nvim_buf_set_extmark(buf, M.ns, match.end_row, match.end_col, {
            ephemeral = true,
            priority = 201,
            virt_text = { { item.label, "MotionToolsLabel" } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
          })
        else
          opts.virt_text = { { item.label, "MotionToolsLabel" } }
          opts.virt_text_pos = "overlay"
          opts.hl_mode = "combine"
        end
      end
      vim.api.nvim_buf_set_extmark(buf, M.ns, row, match.col, opts)
    end
  end,
})

return M
