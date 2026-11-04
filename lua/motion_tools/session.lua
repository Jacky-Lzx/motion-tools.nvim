local Match = require("motion_tools.match")
local View = require("motion_tools.view")
local M = { active = false }
local function key(name)
  return vim.api.nvim_replace_termcodes(name, true, false, true)
end

function M.cancel_operator()
  if vim.fn.mode(true):sub(1, 2) == "no" then
    vim.api.nvim_feedkeys(key("<Esc>"), "ni", false)
  end
end

local function restore(snapshot)
  for win, state in pairs(snapshot) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == state.buf then
      pcall(vim.api.nvim_win_call, win, function()
        vim.fn.winrestview(state.view)
      end)
    end
  end
end

function M.move(match, range)
  local mode = vim.fn.mode(true)
  if
    not vim.api.nvim_win_is_valid(match.win) or vim.api.nvim_win_get_buf(match.win) ~= match.buf
  then
    return false
  end
  vim.cmd("normal! m'")
  vim.api.nvim_set_current_win(match.win)
  if range then
    if mode == "v" or mode == "V" or mode == key("<C-v>") then
      vim.cmd("normal! " .. key("<Esc>"))
    end
    vim.api.nvim_win_set_cursor(match.win, { match.row + 1, match.col })
    local linewise = match.col == 0 and match.end_col == 0 and match.end_row > match.row
    vim.cmd("normal! " .. (linewise and "V" or "v"))
    -- Keep an exact inclusive range, including a trailing newline at EOF.
    -- Restore options after the operator/Visual selection finishes, rather
    -- than changing the meaning of an active selection on the next tick.
    local selection, virtualedit = vim.o.selection, vim.wo.virtualedit
    vim.o.selection, vim.wo.virtualedit = "inclusive", "onemore"
    local group = vim.api.nvim_create_augroup("MotionToolsRange", { clear = true })
    local restored = false
    local function restore_options()
      local current = vim.fn.mode()
      if restored or current == "v" or current == "V" or current == key("<C-v>") then
        return
      end
      restored = true
      if vim.o.selection == "inclusive" then
        vim.o.selection = selection
      end
      if vim.api.nvim_win_is_valid(match.win) and vim.wo[match.win].virtualedit == "onemore" then
        vim.wo[match.win].virtualedit = virtualedit
      end
      vim.api.nvim_clear_autocmds({ group = group })
    end
    vim.api.nvim_create_autocmd("ModeChanged", { group = group, callback = restore_options })
    vim.schedule(restore_options)
    vim.api.nvim_win_set_cursor(match.win, Match.end_pos(match))
  else
    vim.api.nvim_win_set_cursor(match.win, { match.row + 1, match.col })
  end
  vim.cmd("normal! zv")
  return true
end

-- A synchronous reader keeps native operator-pending/Visual semantics intact.
-- UI events are processed by getcharstr(); every exit restores owned UI state.
function M.run(opts)
  if M.active then
    return false
  end
  M.active = true
  local source = vim.api.nvim_get_current_win()
  local snapshot, ticks = {}, {}
  for _, win in ipairs(opts.wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    snapshot[win] = { buf = buf, view = vim.api.nvim_win_call(win, vim.fn.winsaveview) }
    ticks[buf] = vim.api.nvim_buf_get_changedtick(buf)
  end
  local query, prefix, phase = opts.pattern or "", "", opts.immediate and "labels" or "query"
  local selected
  local ok, err = xpcall(function()
    local matches, warning
    local dirty = true
    while true do
      if not vim.api.nvim_win_is_valid(source) then
        break
      end
      if dirty then
        matches, warning = opts.collect(query)
        Match.labels(matches, opts.labels)
        dirty = false
      end
      View.show(matches, prefix, phase == "labels")
      if opts.panel then
        View.panel(matches, prefix)
        vim.cmd.redraw()
      end
      local message = phase == "labels" and ("label: " .. prefix) or ("find: " .. query)
      vim.api.nvim_echo({
        {
          "motion-tools "
            .. message
            .. "  ["
            .. #matches
            .. "]"
            .. (warning and " " .. warning or ""),
          "Question",
        },
      }, false, {})
      local char = vim.fn.getcharstr()
      if char == key("<Esc>") or char == key("<C-c>") then
        break
      end
      local stale = false
      for buf, tick in pairs(ticks) do
        if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_buf_get_changedtick(buf) ~= tick then
          stale = true
        end
      end
      if stale then
        break
      end
      if char == key("<BS>") or char == key("<C-h>") then
        if phase == "labels" and prefix ~= "" then
          prefix = prefix:sub(1, -2)
        elseif phase == "labels" and not opts.immediate then
          phase = "query"
        elseif phase == "query" then
          query = vim.fn.strcharpart(query, 0, math.max(0, vim.fn.strchars(query) - 1))
          dirty = true
        end
      elseif phase == "query" then
        if char == key("<CR>") or char == key("<Tab>") then
          if #matches == 1 then
            selected = matches[1]
            break
          end
          if #matches > 1 then
            phase = "labels"
          end
        elseif char == key("<C-u>") then
          query, dirty = "", true
        elseif vim.fn.strchars(char) == 1 and vim.fn.char2nr(char) >= 32 then
          query, dirty = query .. char, true
        end
      else
        local next_prefix, valid = prefix .. char, false
        for _, match in ipairs(matches) do
          if match.label == next_prefix then
            selected = match
            break
          end
          if match.label:sub(1, #next_prefix) == next_prefix then
            valid = true
          end
        end
        if selected then
          break
        end
        if valid then
          prefix = next_prefix
        end
      end
    end
  end, debug.traceback)
  M.active = false
  View.clear()
  vim.api.nvim_echo({}, false, {})
  restore(snapshot)
  if vim.api.nvim_win_is_valid(source) then
    vim.api.nvim_set_current_win(source)
  end
  if not ok then
    if not tostring(err):find("Vim:Interrupt", 1, true) then
      vim.notify("motion-tools: " .. tostring(err), vim.log.levels.ERROR)
    end
    selected = nil
  end
  if not selected then
    M.cancel_operator()
    return false
  end
  return M.move(selected, opts.range), selected
end

return M
