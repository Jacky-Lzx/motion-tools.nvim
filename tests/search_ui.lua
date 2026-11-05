-- Real UI protocol check: validates rendered cells rather than cached marks.
local uv = vim.uv
local stdin, stdout, stderr = uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false)
local replies, cells, attributes, errors = {}, {}, {}, {}
local next_id, exited = 0, false
local on_frame
local child = assert(uv.spawn(vim.v.progpath, {
  args = { "--embed", "--headless", "-u", "NONE", "-i", "NONE" },
  stdio = { stdin, stdout, stderr },
}, function()
  exited = true
end))
local unpacker = vim.mpack.Unpacker()
stdout:read_start(function(err, data)
  assert(not err, err)
  if not data then
    return
  end
  local pos = 1
  while pos <= #data do
    local message
    message, pos = unpacker(data, pos)
    if message then
      if message[1] == 1 then
        replies[message[2]] = message
      elseif message[1] == 2 and message[2] == "redraw" then
        for _, event in ipairs(message[3]) do
          for i = 2, #event do
            local args = event[i]
            if event[1] == "hl_attr_define" then
              attributes[args[1]] = args[2]
            elseif event[1] == "grid_clear" then
              cells[args[1]] = {}
            elseif event[1] == "grid_scroll" then
              local grid, top, bottom, left, right, rows, cols = unpack(args)
              local previous = vim.deepcopy(cells[grid] or {})
              for row = top, bottom - 1 do
                cells[grid][row] = cells[grid][row] or {}
                for col = left, right - 1 do
                  local source_row, source_col = row + rows, col + cols
                  cells[grid][row][col] = source_row >= top
                      and source_row < bottom
                      and source_col >= left
                      and source_col < right
                      and previous[source_row]
                      and previous[source_row][source_col]
                    or nil
                end
              end
            elseif event[1] == "grid_line" then
              local grid, row, col, last_hl = args[1], args[2], args[3], 0
              cells[grid] = cells[grid] or {}
              cells[grid][row] = cells[grid][row] or {}
              for _, cell in ipairs(args[4]) do
                last_hl = cell[2] or last_hl
                for _ = 1, cell[3] or 1 do
                  cells[grid][row][col] = { text = cell[1], hl = last_hl }
                  col = col + 1
                end
              end
            elseif event[1] == "flush" and on_frame then
              on_frame()
            end
          end
        end
      end
    end
  end
end)
stderr:read_start(function(_, data)
  if data then
    errors[#errors + 1] = data
  end
end)
local function request(method, args)
  next_id = next_id + 1
  local id = next_id
  stdin:write(vim.mpack.encode({ 0, id, method, args }))
  assert(
    vim.wait(5000, function()
      return replies[id] ~= nil or exited
    end, 1),
    "UI RPC timed out: " .. method
  )
  local reply = assert(replies[id], table.concat(errors))
  assert(reply[3] == vim.NIL, vim.inspect(reply[3]))
  return reply[4]
end
local function lua(code, args)
  return request("nvim_exec_lua", { code, args or {} })
end
local function ready()
  assert(vim.wait(5000, function()
    return not lua("return require('pairs.rainbow').status().pending")
  end, 1))
  request("nvim_command", { "redraw" })
end
-- A scheduled float redraw exposes source frames produced between native
-- incsearch and the next input-loop redraw. Inspect every flushed frame.
local watching, checked, bad = false, 0, {}
local current_row
on_frame = function()
  if not watching then
    return
  end
  checked = checked + 1
  for _, row in ipairs({ 15, 20 }) do
    local cell = cells[1] and cells[1][row] and cells[1][row][0]
    local expected = row == current_row and 0x00ff00 or 0xff0000
    if not cell or cell.text ~= "n" or (attributes[cell.hl] or {}).background ~= expected then
      bad[#bad + 1] = { row = row, cell = cell, color = cell and attributes[cell.hl] }
    end
  end
end
local function input(keys)
  request("nvim_input", { keys })
  vim.wait(50)
end
local function marks()
  return lua([[return #vim.api.nvim_buf_get_extmarks(source_buf,
    require('motion_tools.search').ns,0,-1,{})]])
end
local ok, err = xpcall(function()
  request("nvim_ui_attach", { 120, 36, { rgb = true, ext_linegrid = true } })
  lua([[
    vim.opt.rtp:prepend(vim.fn.getcwd())
    vim.o.swapfile, vim.o.termguicolors = false, true
    vim.o.hlsearch, vim.o.incsearch = true, true
    vim.o.showmode, vim.o.ruler = false, false
    vim.o.laststatus, vim.o.scrolloff = 0, 0
    vim.api.nvim_set_hl(0,'Search',{bg=0xff0000})
    vim.api.nvim_set_hl(0,'IncSearch',{bg=0x00ff00})
    vim.api.nvim_set_hl(0,'CurSearch',{bg=0x0000ff})
    local lines={}; for i=1,30 do lines[i]='' end
    lines[16],lines[21]='normalized','normalized'
    vim.api.nvim_buf_set_lines(0,0,-1,false,lines)
    source_buf=vim.api.nvim_get_current_buf()
    require('motion_tools').setup()
    local b=vim.api.nvim_create_buf(false,true)
    vim.api.nvim_open_win(b,false,{relative='editor',row=3,col=10,width=30,height=1,style='minimal'})
    vim.api.nvim_create_autocmd('CmdlineChanged',{callback=function()
      vim.schedule(function() vim.cmd.redraw() end)
    end})
    if vim.env.INPUT_TOOLS_PATH then
      vim.opt.rtp:prepend(vim.env.INPUT_TOOLS_PATH)
      require('input-tools').setup({status=false,window={row=3}})
    end
    if vim.env.COMPLETION_TOOLS_PATH then
      vim.opt.rtp:prepend(vim.env.COMPLETION_TOOLS_PATH)
      require('completion-tools').setup({sources={},documentation={auto_show=false},cmdline={enabled=true,
        get_anchor=function()
          local input=package.loaded['input-tools'];local b=input and input.get_layout()
          return b and {row=b.row,col=b.col,height=b.outer_height}
        end}})
    end
  ]])
  for _, kind in ipairs({ "/", "?" }) do
    for _, ending in ipairs({ "<CR>", "<Esc>" }) do
      current_row = kind == "/" and 15 or 20
      lua(
        [[
        local reverse=...
        vim.api.nvim_win_set_cursor(0,{reverse and 30 or 1,0})
        vim.fn.setreg('/','normal')
        vim.v.hlsearch=1
        require('motion_tools').lens()
        vim.cmd.redraw()
      ]],
        { kind == "?" }
      )
      assert(marks() == 1, "initial counter missing")
      input(kind .. "norm")
      watching, checked, bad = true, 0, {}
      for _, keys in ipairs({
        "a",
        "l",
        "i",
        "z",
        "e",
        "d",
        "<BS>",
        "<BS>",
        "ed",
        "<Left>",
        "<Right>",
      }) do
        input(keys)
      end
      watching = false
      assert(checked > 0, "no incremental-search frames captured")
      assert(#bad == 0, kind .. " search highlight flickered: " .. vim.inspect(bad))
      assert(marks() == 0, "counter stayed visible during command-line editing")
      input(ending)
      assert(lua("return vim.api.nvim_get_mode().mode") == "n")
      assert(lua("return vim.fn.getreg('/')") == (ending == "<CR>" and "normalized" or "normal"))
      assert(marks() == 1, "counter did not recover after " .. ending)
      assert(
        lua(
          [[return vim.api.nvim_buf_get_extmarks(source_buf,
        require('motion_tools.search').ns,0,-1,{details=true})[1][4].virt_text[1][1]:find('/2',1,true)~=nil]]
        )
      )
      print(
        "search UI: "
          .. kind
          .. " typing, deletion, burst input and "
          .. ending
          .. " passed ("
          .. checked
          .. " frames)"
      )
    end
  end
  input(":nohlsearch<CR>")
  assert(marks() == 0, "nohlsearch left a counter")
end, debug.traceback)
child:kill("sigterm")
vim.wait(100)
assert(ok, err)
