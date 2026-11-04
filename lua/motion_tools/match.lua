local M = {}

-- Public ranges use zero-based byte columns and an exclusive end, like Tree-sitter.
function M.range(win, row, col, end_row, end_col)
  return {
    win = win,
    buf = vim.api.nvim_win_get_buf(win),
    row = row,
    col = col,
    end_row = end_row,
    end_col = end_col,
  }
end

function M.windows(multi, mode)
  local current = vim.api.nvim_get_current_win()
  local wins = { current }
  -- Operators and Visual selections stay in their source window: a range cannot
  -- span buffers. Normal mode can jump to any ordinary window in this tab.
  if multi and mode == "n" then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if
        win ~= current
        and vim.api.nvim_win_get_config(win).relative == ""
        and vim.bo[buf].buftype == ""
      then
        wins[#wins + 1] = win
      end
    end
  end
  return wins
end

function M.pattern(query, regex)
  if regex then
    return query
  end
  local case = vim.o.ignorecase and not (vim.o.smartcase and query:find("%u"))
  return (case and "\\c" or "\\C") .. "\\V" .. query:gsub("\\", "\\\\")
end

function M.collect(wins, query, opts)
  opts = opts or {}
  if query == "" and not opts.lines then
    return {}
  end
  local pattern = M.pattern(query, opts.regex)
  local ok = pcall(vim.regex, pattern)
  if not ok then
    return {}, "Invalid pattern"
  end
  local matches, limit = {}, opts.max_matches or 1000
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_call(win, function()
        local buf = vim.api.nvim_win_get_buf(win)
        local first, last = vim.fn.line("w0"), vim.fn.line("w$")
        local lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, false)
        for index, line in ipairs(lines) do
          local row = first + index - 2
          -- Closed folds offer only their header; hidden rows never get labels.
          local closed = vim.fn.foldclosed(row + 1)
          if closed == -1 or closed == row + 1 then
            local occurrence = 1
            while #matches < limit do
              local start, finish
              if opts.lines then
                start = line:find("%S")
                if start then
                  start, finish = start - 1, start
                end
              else
                -- Keep the original start so ^ and look-behind retain their
                -- meaning. Vim advances zero-width matches by whole characters.
                local result = vim.fn.matchstrpos(line, pattern, 0, occurrence)
                start, finish = result[2], result[3]
                if start == -1 then
                  start = nil
                end
              end
              if not start then
                break
              end
              local screen = vim.fn.screenpos(win, row + 1, start + 1)
              if screen.row > 0 and screen.col > 0 then
                matches[#matches + 1] = M.range(win, row, start, row, finish)
              end
              if opts.lines or finish >= #line then
                break
              end
              occurrence = occurrence + 1
            end
          end
          if #matches >= limit then
            break
          end
        end
      end)
    end
    if #matches >= limit then
      break
    end
  end
  local current = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(current)
  table.sort(matches, function(a, b)
    if a.win ~= b.win then
      if a.win == current then
        return true
      end
      if b.win == current then
        return false
      end
      return a.win < b.win
    end
    local da = math.abs(a.row + 1 - cursor[1]) * 10000 + math.abs(a.col - cursor[2])
    local db = math.abs(b.row + 1 - cursor[1]) * 10000 + math.abs(b.col - cursor[2])
    if da ~= db then
      return da < db
    end
    if a.row ~= b.row then
      return a.row < b.row
    end
    return a.col < b.col
  end)
  return matches, #matches >= limit and "Match limit reached" or nil
end

function M.labels(matches, alphabet)
  local width, capacity = 1, #alphabet
  while capacity < #matches do
    width, capacity = width + 1, capacity * #alphabet
  end
  for index, match in ipairs(matches) do
    local value, label = index - 1, ""
    for _ = 1, width do
      local digit = value % #alphabet + 1
      label = alphabet:sub(digit, digit) .. label
      value = math.floor(value / #alphabet)
    end
    match.label = label
  end
  return matches
end

-- Scan every visible line, independently of the collected-result cap. Include
-- overlapping occurrences: extending "aa" in "aaas" must keep both a and s free.
function M.continuations(wins, query, alphabet)
  local blocked = {}
  if query == "" then
    return blocked
  end
  local pattern = M.pattern(query, false)
  local insensitive = vim.o.ignorecase and not (vim.o.smartcase and query:find("%u"))
  local remaining = alphabet or "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  for _, win in ipairs(wins) do
    if remaining == "" then
      break
    end
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_call(win, function()
        local first, last = vim.fn.line("w0"), vim.fn.line("w$")
        local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
        for index, line in ipairs(lines) do
          if remaining == "" then
            break
          end
          local row = first + index - 1
          local closed = vim.fn.foldclosed(row)
          if closed == -1 or closed == row then
            -- Each successful scan removes a letter from consideration. Even a
            -- very repetitive line needs at most one scan per label letter.
            while remaining ~= "" do
              local char = vim.fn.matchstr(line, pattern .. "\\m\\zs[" .. remaining .. "]")
              if char == "" then
                break
              end
              blocked[char] = true
              if insensitive then
                -- Conservatively exclude both cases, including smartcase
                -- changes caused by appending an uppercase label.
                blocked[char:lower()], blocked[char:upper()] = true, true
              end
              remaining = remaining:gsub(".", function(candidate)
                return blocked[candidate] and "" or candidate
              end)
            end
          end
        end
      end)
    end
  end
  return blocked
end

function M.live_labels(matches, alphabet, blocked, previous)
  previous = previous or {}
  local available, identities = {}, {}
  for char in alphabet:gmatch(".") do
    available[char] = not blocked[char]
  end
  -- Reserve surviving labels before assigning any new ones.
  for index, match in ipairs(matches) do
    match.live_label = nil
    local pos = vim.fn.screenpos(match.win, match.end_row + 1, match.end_col + 1)
    if pos.row > 0 and pos.col > 0 then
      local id = table.concat({ match.win, match.buf, match.row, match.col }, ":")
      identities[index] = id
      local label = previous[id]
      if available[label] then
        match.live_label, available[label] = label, false
      end
    end
  end
  for index, match in ipairs(matches) do
    if identities[index] and not match.live_label then
      for char in alphabet:gmatch(".") do
        if available[char] then
          match.live_label, available[char] = char, false
          previous[identities[index]] = char
          break
        end
      end
    end
  end
  return previous
end

function M.end_pos(match)
  local row, col = match.end_row, match.end_col
  if col == 0 and row > match.row then
    row = row - 1
    col = #vim.api.nvim_buf_get_lines(match.buf, row, row + 1, false)[1]
    return { row + 1, col } -- The previous line's newline belongs to the range.
  end
  local line = vim.api.nvim_buf_get_lines(match.buf, row, row + 1, false)[1] or ""
  if col > 0 then
    local prefix = line:sub(1, col)
    col = col - #vim.fn.strcharpart(prefix, vim.fn.strchars(prefix) - 1, 1)
  end
  return { row + 1, math.max(col, 0) }
end

return M
