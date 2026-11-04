vim.opt.runtimepath:prepend(vim.fn.getcwd())
if vim.env.MOTION_TOOLS_PARSER_DIR then
  vim.opt.runtimepath:append(vim.env.MOTION_TOOLS_PARSER_DIR)
end
vim.o.swapfile, vim.o.shadafile = false, "NONE"
vim.o.timeoutlen, vim.o.ttimeoutlen = 250, 20
vim.g.mapleader = " "
local tools = require("motion_tools")
local View = require("motion_tools.view")
local Session = require("motion_tools.session")
tools.setup({ labels = "asdf", mappings = true })
vim.keymap.set({ "n", "x", "o" }, " m", function()
  tools.treesitter({ search = true })
end)
local directory = assert(vim.env.MOTION_TOOLS_TEST_DIR)
local origin = vim.api.nvim_get_current_win()
local buf = vim.api.nvim_get_current_buf()
local tests, index, finished, assertions, executed = {}, 0, false, 0, 0
local errors = {}
vim.notify = function(message, level)
  if level == vim.log.levels.ERROR then
    errors[#errors + 1] = tostring(message)
  end
end
local function check(value, message)
  assert(value, message)
  assertions = assertions + 1
end
local function text()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end
local function position(row, col)
  check(
    vim.deep_equal(vim.api.nvim_win_get_cursor(0), { row, col }),
    "position: " .. vim.inspect(vim.api.nvim_win_get_cursor(0))
  )
end
local function reset(lines, row, col)
  vim.cmd("silent! normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
  vim.api.nvim_set_current_win(origin)
  vim.cmd("silent! only!")
  vim.api.nvim_win_set_buf(origin, buf)
  vim.bo[buf].filetype = ""
  vim.o.selection, vim.wo.virtualedit = "inclusive", ""
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { "alpha beta gamma", "  beta", "tail" })
  vim.api.nvim_win_set_cursor(origin, { row or 1, col or 0 })
  vim.fn.setreg("/", "previous-search")
  vim.fn.setreg("a", "")
end
local function case(name, input, setup, verify)
  tests[#tests + 1] = { name = name, input = input, setup = setup, verify = verify }
end
case("literal", " fgam\r", reset, function()
  position(1, 11)
  check(vim.fn.getreg("/") == "previous-search", "jump changed search register")
end)
case("cancel", " fbeta\r\27", function()
  reset()
  vim.fn.winrestview({ topline = 1, lnum = 2, col = 2 })
  tests[index].view = vim.fn.winsaveview()
  tests[index].jumps = vim.fn.getjumplist()
end, function()
  check(vim.deep_equal(vim.fn.winsaveview(), tests[index].view), "cancel changed view")
  check(vim.deep_equal(vim.fn.getjumplist(), tests[index].jumps), "cancel changed jumplist")
end)
case("operator-delete", "d fgam\r", reset, function()
  check(text() == "gamma\n  beta\ntail", "operator delete: " .. text())
  check(vim.fn.mode() == "n", "delete mode")
end)
case("operator-register", '"ay fgam\r', reset, function()
  check(vim.fn.getreg("a") == "alpha beta ", "yank register: " .. vim.fn.getreg("a"))
  check(text():find("alpha", 1, true), "yank changed text")
end)
case("operator-cancel", "d fbeta\27", reset, function()
  check(text() == "alpha beta gamma\n  beta\ntail", "cancel executed operator")
  check(vim.fn.mode() == "n", "operator not cancelled")
end)
case("visual", "v fgam\r", reset, function()
  check(vim.fn.mode() == "v", "visual lost")
  position(1, 11)
  check(vim.fn.getpos("v")[3] == 1, "visual anchor moved")
end)
case("visual-reversed", "v fbeta\ra", function()
  reset(nil, 1, 14)
end, function()
  check(vim.fn.mode() == "v", "reversed visual lost")
  position(1, 6)
  check(vim.fn.getpos("v")[3] == 15, "reversed anchor moved")
end)
case("visual-line", "V fgam\r", reset, function()
  check(vim.fn.mode() == "V", "linewise visual lost")
end)
case("visual-block", "\22 fgam\r", reset, function()
  check(vim.fn.mode() == "\22", "blockwise visual lost")
end)
case("line-jump", " jd", reset, function()
  position(3, 0)
end)
case("backspace", " fbetx\127a\ra", reset, function()
  position(1, 6)
end)
case("unicode", " f中文\ra", function()
  reset({ "zero 中文 end", "中文" })
end, function()
  position(1, 5)
end)
case("label-prefix", " fword\rsa", function()
  reset({ "word word word word word word word word" })
end, function()
  position(1, 20)
end)
local remote
case("cross-window", " ftar\r", function()
  reset({ "source" })
  vim.cmd("vnew")
  remote = vim.api.nvim_get_current_win()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "remote target" })
  vim.api.nvim_set_current_win(origin)
end, function()
  check(vim.api.nvim_get_current_win() == remote, "remote window not selected")
  position(1, 7)
end)
case("jumplist", " ftail\r\15", function()
  reset()
  vim.cmd("clearjumps")
end, function()
  position(1, 0)
end)
case("native-search", "/beta\r", reset, function()
  position(1, 6)
  check(
    #vim.api.nvim_buf_get_extmarks(buf, require("motion_tools.search").ns, 0, -1, {}) == 1,
    "native / lens missing"
  )
end)
case("search-count", "2n", function()
  reset({ "beta beta beta beta" })
  vim.fn.setreg("/", "beta")
  vim.v.searchforward = 1
end, function()
  position(1, 10)
  check(vim.fn.searchcount({ recompute = 1 }).current == 3, "native count changed")
end)
case("search-backwards", "N", function()
  reset({ "beta beta beta beta" }, 1, 10)
  vim.fn.setreg("/", "beta")
  vim.v.searchforward = 1
end, function()
  position(1, 5)
end)
case("word-search", "*", function()
  reset({ "beta beta beta" })
end, function()
  position(1, 5)
  check(vim.fn.getreg("/") == "\\<beta\\>", "word search pattern")
end)
case("cmdline-label", "/beta\6s", reset, function()
  position(2, 2)
  check(vim.fn.getreg("/") == "beta", "cmdline search register")
end)
case("cmdline-cancel", "/beta\6\27", reset, function()
  position(1, 0)
  check(vim.fn.getreg("/") == "previous-search", "cancelled search changed register")
end)
case("indent-operator", "d]i", function()
  reset({ "root", "  child", "tail" })
end, function()
  check(text() == "child\ntail", "indent operator: " .. text())
end)
case("diagnostic-count", "2]d", function()
  reset({ "one", "two", "three", "four" })
  vim.diagnostic.set(
    vim.api.nvim_create_namespace("tui"),
    buf,
    { { lnum = 1, col = 0, message = "one" }, { lnum = 3, col = 0, message = "two" } }
  )
end, function()
  position(4, 0)
end)
if vim.env.MOTION_TOOLS_PARSER_DIR then
  local function lua_source()
    reset({ "local word = '中文'", "print(word)" }, 1, 7)
    vim.bo.filetype = "lua"
  end
  case("syntax-visual", " F a", lua_source, function()
    check(vim.fn.mode() == "v", "syntax selection lost")
    position(1, 9)
    check(vim.fn.getpos("v")[3] == 7, "syntax start")
  end)
  case("syntax-yank", '"ay Fa', lua_source, function()
    check(vim.fn.getreg("a") == "word", "syntax yank: " .. vim.fn.getreg("a"))
    check(not View.panel_win, "syntax panel leaked")
  end)
  case("syntax-exclusive", '"ay Fa', function()
    lua_source()
    vim.o.selection = "exclusive"
  end, function()
    check(vim.fn.getreg("a") == "word", "exclusive syntax yank: " .. vim.fn.getreg("a"))
  end)
  case("syntax-search", '"ay mword\ra', lua_source, function()
    check(vim.fn.getreg("a") == "word", "syntax search yank")
  end)
  case("syntax-eol-exclusive", '"ay Faa', function()
    reset({ "local x = '中文'" }, 1, 13)
    vim.bo.filetype = "lua"
    vim.o.selection = "exclusive"
  end, function()
    check(vim.fn.getreg("a") == "中文", "exclusive EOL/UTF-8 range: " .. vim.fn.getreg("a"))
  end)
  case("syntax-root", '"ay Ff', lua_source, function()
    check(
      vim.fn.getreg("a") == "local word = '中文'\nprint(word)\n",
      "root range at EOF: " .. vim.fn.getreg("a")
    )
  end)
  case("syntax-root-exclusive", '"ay Ff', function()
    lua_source()
    vim.o.selection = "exclusive"
  end, function()
    check(
      vim.fn.getreg("a") == "local word = '中文'\nprint(word)\n",
      "exclusive root range at EOF"
    )
    check(vim.o.selection == "exclusive" and vim.wo.virtualedit == "", "range options leaked")
  end)
end

local function finish(ok, message)
  if finished then
    return
  end
  finished = true
  vim.fn.writefile({ (ok and "PASS " or "FAIL ") .. message }, directory .. "/result")
  vim.cmd(ok and "qa!" or "cquit 1")
end
local function next_case()
  index = index + 1
  while
    tests[index]
    and vim.env.MOTION_TOOLS_TEST_FILTER
    and not tests[index].name:find(vim.env.MOTION_TOOLS_TEST_FILTER, 1, true)
  do
    index = index + 1
  end
  if index > #tests then
    check(#errors == 0, "error notifications: " .. table.concat(errors, "\n"))
    finish(true, executed .. " real PTY workflows / " .. assertions .. " assertions")
    return
  end
  executed = executed + 1
  tests[index].setup()
  vim.cmd.redraw()
  vim.fn.writefile(
    { index .. ":" .. tests[index].name, vim.json.encode(tests[index].input) },
    directory .. "/stage"
  )
end
vim.keymap.set({ "n", "x" }, "<F12>", function()
  vim.schedule(function()
    local ok, err = xpcall(function()
      check(not Session.active and next(View.windows) == nil, "jump state leaked")
      tests[index].verify()
      next_case()
    end, debug.traceback)
    if not ok then
      finish(false, tests[index].name .. ": " .. err)
    end
  end)
end)
vim.defer_fn(function()
  local ok, err = pcall(next_case)
  if not ok then
    finish(false, tostring(err))
  end
end, 100)
vim.defer_fn(function()
  finish(false, "timeout at " .. (tests[index] and tests[index].name or "start"))
end, 20000)
