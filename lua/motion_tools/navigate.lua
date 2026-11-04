local Match = require("motion_tools.match")
local Session = require("motion_tools.session")
local M = {}

-- Choose from ordered integer keys, allowing holes (invalid quickfix entries).
function M.index(keys, current, direction, count, wrap)
  if #keys == 0 then
    return nil
  end
  if direction == "first" then
    return keys[math.min(count, #keys)]
  end
  if direction == "last" then
    return keys[math.max(1, #keys - count + 1)]
  end
  local index
  if direction == "next" then
    index = #keys + 1
    for i, value in ipairs(keys) do
      if value > current then
        index = i
        break
      end
    end
    index = index + count - 1
  else
    index = 0
    for i = #keys, 1, -1 do
      if keys[i] < current then
        index = i
        break
      end
    end
    index = index - count + 1
  end
  if wrap then
    index = (index - 1) % #keys + 1
  else
    index = math.max(1, math.min(index, #keys))
  end
  return keys[index]
end

local function position(items, direction, opts)
  table.sort(items, function(a, b)
    return a.row == b.row and a.col < b.col or a.row < b.row
  end)
  local unique, keys = {}, {}
  for _, item in ipairs(items) do
    local value = item.row * 2147483648 + item.col
    if keys[#keys] ~= value then
      keys[#keys + 1], unique[value] = value, item
    end
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local value =
    M.index(keys, (cursor[1] - 1) * 2147483648 + cursor[2], direction, opts.count, opts.wrap)
  return value and Session.move(unique[value], false) or false
end

function M.run(target, direction, opts)
  opts = vim.tbl_extend("force", { count = vim.v.count1, wrap = true }, opts or {})
  assert(
    vim.tbl_contains({ "next", "prev", "first", "last" }, direction),
    "motion-tools: invalid direction"
  )
  assert(
    type(opts.count) == "number" and opts.count >= 1 and opts.count % 1 == 0,
    "motion-tools: count must be a positive integer"
  )
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  if target == "buffer" then
    local keys = vim.tbl_filter(function(b)
      return vim.bo[b].buflisted
    end, vim.api.nvim_list_bufs())
    table.sort(keys)
    local next_buf = M.index(keys, buf, direction, opts.count, opts.wrap)
    if not next_buf or next_buf == buf then
      return false
    end
    vim.api.nvim_set_current_buf(next_buf)
    return true
  elseif target == "quickfix" or target == "location" then
    local list = target == "quickfix" and vim.fn.getqflist({ items = 0, idx = 0 })
      or vim.fn.getloclist(0, { items = 0, idx = 0 })
    local keys = {}
    for i, item in ipairs(list.items) do
      if item.valid == 1 then
        keys[#keys + 1] = i
      end
    end
    local index = M.index(keys, list.idx, direction, opts.count, opts.wrap)
    if not index then
      return false
    end
    vim.cmd({ cmd = target == "quickfix" and "cc" or "ll", count = index })
    return true
  elseif target == "jump" then
    local list, index = unpack(vim.fn.getjumplist())
    if #list == 0 then
      return false
    end
    local count = opts.count
    if direction == "first" then
      count = index
      direction = "prev"
    elseif direction == "last" then
      count = #list - index
      direction = "next"
    end
    if count == 0 then
      return false
    end
    vim.cmd.normal({
      count .. vim.api.nvim_replace_termcodes(
        direction == "next" and "<C-i>" or "<C-o>",
        true,
        false,
        true
      ),
      bang = true,
    })
    return true
  elseif target == "diagnostic" then
    local items = {}
    for _, diagnostic in ipairs(vim.diagnostic.get(buf, { severity = opts.severity })) do
      items[#items + 1] = { win = win, buf = buf, row = diagnostic.lnum, col = diagnostic.col }
    end
    return position(items, direction, opts)
  elseif target == "indent" then
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local step = (direction == "prev" or direction == "first") and -1 or 1
    local times = (direction == "first" or direction == "last") and vim.api.nvim_buf_line_count(buf)
      or opts.count
    local found = false
    for _ = 1, times do
      local level, next_row = vim.fn.indent(row), nil
      for line = row + step, (step == 1 and vim.api.nvim_buf_line_count(buf) or 1), step do
        if vim.fn.getline(line):find("%S") then
          local indent = vim.fn.indent(line)
          if
            (opts.change == "more" and indent > level)
            or (opts.change == "less" and indent < level)
            or (opts.change == nil and indent ~= level)
          then
            next_row = line
            break
          end
        end
      end
      if not next_row then
        break
      end
      row, found = next_row, true
    end
    if not found then
      return false
    end
    return Session.move(
      { win = win, buf = buf, row = row - 1, col = vim.fn.getline(row):find("%S") - 1 },
      false
    )
  elseif target == "treesitter" then
    local nodes = require("motion_tools.treesitter").ancestors(win)
    local items = {}
    local forward = direction == "next" or direction == "last"
    for _, node in ipairs(nodes) do
      local pos = forward and Match.end_pos(node) or { node.row + 1, node.col }
      items[#items + 1] = { win = win, buf = buf, row = pos[1] - 1, col = pos[2] }
    end
    opts.wrap = false
    return position(items, direction, opts)
  end
  error("motion-tools: unknown navigation target " .. tostring(target))
end

return M
