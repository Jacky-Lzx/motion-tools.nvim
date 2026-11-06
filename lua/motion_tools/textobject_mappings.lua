local M = {}
local function read_id()
  local ok, id = pcall(vim.fn.getcharstr)
  if not ok or id == "\27" or id == "\3" then
    return nil
  end
  return id
end

function M.setup(map, defaults)
  local config = require("motion_tools.config").options.textobjects
  for _, kind in ipairs({ "inside", "around" }) do
    for _, direction in ipairs({ "current", "next", "prev" }) do
      local name = kind .. (direction == "current" and "" or "_" .. direction)
      for _, mode in ipairs({ "o", "x" }) do
        local function select_object()
          local id = read_id()
          if not id then
            return "<Esc>"
          end
          -- Native objects remain native, including user-defined word/sentence motions.
          local builtins = { w = true, W = true, s = true, p = true }
          if
            builtins[id]
            and direction == "current"
            and config.objects[id] == nil
            and not config.treesitter[id]
          then
            return (kind == "inside" and "i" or "a") .. id
          end
          local count = vim.v.count1
          return "<Cmd>lua require('motion_tools')._select_object("
            .. vim.inspect(id)
            .. ","
            .. vim.inspect(kind)
            .. ","
            .. vim.inspect(direction)
            .. ","
            .. count
            .. ","
            .. tostring(mode == "o")
            .. ","
            .. vim.inspect(vim.v.register)
            .. ")<CR>"
        end
        local plug = "<Plug>(MotionTools-" .. name .. ")"
        map({ mode }, plug, select_object, name .. " text object", true)
        local lhs = config.mappings[name]
        if (not lhs or lhs == "") and defaults then
          lhs = ({
            inside = "i",
            around = "a",
            inside_next = "in",
            around_next = "an",
            inside_prev = "il",
            around_prev = "al",
          })[name]
        end
        if lhs and lhs ~= "" then
          map({ mode }, lhs, plug, name .. " text object")
        end
      end
    end
  end
  for lhs, edge in pairs({ ["g["] = "start", ["g]"] = "end" }) do
    local action = "goto_" .. edge
    local plug = "<Plug>(MotionTools-" .. action .. ")"
    map({ "n" }, plug, function()
      require("motion_tools").object_boundary(edge)
    end, "Object " .. edge)
    local key = config.mappings[action] or (defaults and lhs)
    if key and key ~= "" then
      map({ "n" }, key, plug, "Object " .. edge)
    end
  end
end
return M
