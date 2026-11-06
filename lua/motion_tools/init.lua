local Config = require("motion_tools.config")
local M = {}

function M.setup(opts)
  assert(opts == nil or type(opts) == "table", "motion-tools.nvim: setup expects a table")
  opts = vim.deepcopy(opts or {})
  local options = Config.resolve(opts)
  Config.options = options
  require("motion_tools.view").highlights()
  require("motion_tools.search").setup()
  require("motion_tools.mappings").setup(options.mappings)
end

function M.dispose()
  local session = package.loaded["motion_tools.session"]
  if session then
    session.cancel()
  end
  local search = package.loaded["motion_tools.search"]
  if search then
    search.dispose()
  end
  local mappings = package.loaded["motion_tools.mappings"]
  if mappings then
    mappings.setup(false)
  end
  local repeat_state = package.loaded["motion_tools.repeat"]
  if repeat_state then
    repeat_state.dispose()
  end
  Config.options = Config.resolve()
end

function M.jump(opts)
  opts = opts or {}
  local Match = require("motion_tools.match")
  local mode = vim.fn.mode(true)
  local wins = Match.windows(
    opts.multi_window == nil and Config.options.multi_window or opts.multi_window,
    mode
  )
  local labels = Config.options.labels
  if opts.lines then
    -- Keep the configured order, then add missing letters of the opposite case.
    for char in Config.options.labels:gmatch(".") do
      local other = char:match("%l") and char:upper() or char:lower()
      if not labels:find(other, 1, true) then
        labels = labels .. other
      end
    end
  end
  local live_labels = opts.live_labels
  if live_labels == nil then
    live_labels = Config.options.live_labels
  end
  require("motion_tools.search").clear()
  return require("motion_tools.session").run({
    kind = opts.lines and "lines" or opts.treesitter and "syntax_search" or "jump",
    wins = wins,
    labels = labels,
    live_labels = live_labels
      and opts.pattern == nil
      and not opts.regex
      and not opts.lines
      and not opts.treesitter,
    pattern = opts.pattern,
    immediate = opts.pattern ~= nil,
    range = opts.range,
    collect = function(query)
      local options =
        { regex = opts.regex, lines = opts.lines, max_matches = Config.options.max_matches }
      if opts.treesitter then
        return require("motion_tools.treesitter").search(wins, query, options)
      end
      return Match.collect(wins, query, options)
    end,
  })
end

function M.lines(opts)
  return M.jump(vim.tbl_extend("force", opts or {}, { pattern = "", lines = true }))
end

function M.treesitter(opts)
  opts = opts or {}
  if opts.search then
    return M.jump(
      vim.tbl_extend("force", opts, { treesitter = true, range = true, multi_window = false })
    )
  end
  local win = vim.api.nvim_get_current_win()
  local nodes, warning = require("motion_tools.treesitter").ancestors(win)
  if #nodes == 0 then
    require("motion_tools.session").cancel_operator()
    if warning then
      vim.notify("motion-tools: " .. warning, vim.log.levels.INFO)
    end
    return false
  end
  return require("motion_tools.session").run({
    kind = "syntax",
    wins = { win },
    labels = Config.options.labels,
    immediate = true,
    range = true,
    panel = true,
    collect = function()
      return nodes
    end,
  })
end

function M.navigate(target, direction, opts)
  local ok, result = pcall(require("motion_tools.navigate").run, target, direction or "next", opts)
  if not ok then
    vim.notify(tostring(result), vim.log.levels.WARN)
  end
  if not ok or not result then
    require("motion_tools.session").cancel_operator()
  end
  return ok and result or false
end

function M.search(key)
  assert(
    vim.tbl_contains({ "n", "N", "*", "#", "g*", "g#" }, key),
    "motion-tools: invalid search key"
  )
  local ok, err = pcall(vim.cmd.normal, { vim.v.count1 .. key, bang = true })
  if not ok then
    vim.notify(tostring(err), vim.log.levels.INFO)
    return false
  end
  if Config.options.search.center and (key == "n" or key == "N") then
    vim.cmd("normal! zz")
  end
  require("motion_tools.search").show()
  return true
end

function M.lens()
  require("motion_tools.search").show()
end

-- Use as an expression mapping in / or ? command-line mode.
function M.cmdline_jump()
  local kind = vim.fn.getcmdtype()
  if kind ~= "/" and kind ~= "?" then
    return "<C-f>"
  end
  local pattern = vim.fn.getcmdline()
  if pattern == "" then
    pattern = vim.fn.getreg("/")
  end
  local command = ("<C-c><Cmd>lua require('motion_tools')._cmdline_jump(%q, %q)<CR>"):format(
    pattern,
    kind
  )
  return command
end

function M._cmdline_jump(pattern, kind)
  if pattern == "" then
    return false
  end
  local moved = M.jump({ pattern = pattern, regex = true })
  if moved then
    vim.fn.setreg("/", pattern)
    vim.fn.histadd("search", pattern)
    vim.v.searchforward = kind == "/" and 1 or 0
    vim.o.hlsearch = true
    vim.v.hlsearch = 1
    M.lens()
  end
  return moved
end

return M
