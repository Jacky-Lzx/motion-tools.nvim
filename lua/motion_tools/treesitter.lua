local Match = require("motion_tools.match")
local M = {}

local function parser(buf)
  local ok, value = pcall(vim.treesitter.get_parser, buf)
  if not ok or not value then
    return nil
  end
  local parsed = pcall(value.parse, value, true)
  return parsed and value or nil
end

function M.ancestors(win, pos, language_tree)
  local buf = vim.api.nvim_win_get_buf(win)
  local p = language_tree or parser(buf)
  if not p then
    return {}, "No Tree-sitter parser"
  end
  pos = pos or vim.api.nvim_win_get_cursor(win)
  local matches, seen = {}, {}
  p:for_each_tree(function(tree)
    local root = tree:root()
    local sr, sc, er, ec = root:range()
    local row, col = pos[1] - 1, pos[2]
    if row < sr or row > er or (row == sr and col < sc) or (row == er and col >= ec) then
      return
    end
    local node = root:named_descendant_for_range(row, col, row, col)
    while node do
      local row, col, erow, ecol = node:range()
      local id = table.concat({ row, col, erow, ecol }, ":")
      if not seen[id] and (row ~= erow or col ~= ecol) then
        seen[id] = true
        local match = Match.range(win, row, col, erow, ecol)
        match.kind = node:type()
        matches[#matches + 1] = match
      end
      node = node:parent()
    end
  end)
  table.sort(matches, function(a, b)
    if a.row ~= b.row then
      return a.row > b.row
    end
    if a.col ~= b.col then
      return a.col > b.col
    end
    if a.end_row ~= b.end_row then
      return a.end_row < b.end_row
    end
    return a.end_col < b.end_col
  end)
  return matches
end

function M.search(wins, query, opts)
  local results, warning = Match.collect(wins, query, opts)
  local matches, seen, parsers = {}, {}, {}
  for _, result in ipairs(results) do
    if parsers[result.buf] == nil then
      parsers[result.buf] = parser(result.buf) or false
    end
    local nodes = parsers[result.buf]
        and M.ancestors(result.win, { result.row + 1, result.col }, parsers[result.buf])
      or {}
    local node = nodes[1]
    if node then
      local id = table.concat({ node.win, node.row, node.col, node.end_row, node.end_col }, ":")
      if not seen[id] then
        seen[id] = true
        matches[#matches + 1] = node
      end
    end
  end
  return matches, warning
end

return M
