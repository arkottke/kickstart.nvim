-- Minimal which-key.nvim approximation, built only on nvim_get_keymap(),
-- getcharstr() and a floating window. Bound to the bare leader key itself:
-- pressing <leader> and pausing shows the available continuations (reusing
-- each mapping's `desc`); typing a full sequence replays it normally.

local M = {}

local function get_prefixed(prefix)
  local groups = {}
  for _, maps in ipairs { vim.api.nvim_get_keymap 'n', vim.api.nvim_buf_get_keymap(0, 'n') } do
    for _, m in ipairs(maps) do
      if #m.lhs > #prefix and m.lhs:sub(1, #prefix) == prefix then
        local nextchar = m.lhs:sub(#prefix + 1, #prefix + 1)
        groups[nextchar] = groups[nextchar] or { count = 0 }
        groups[nextchar].count = groups[nextchar].count + 1
        if #m.lhs == #prefix + 1 then groups[nextchar].desc = m.desc end
      end
    end
  end
  local items = {}
  for key, g in pairs(groups) do
    local desc = (g.count > 1) and ('+' .. g.count .. ' more') or (g.desc or key)
    items[#items + 1] = { key = key, desc = desc }
  end
  table.sort(items, function(a, b) return a.key < b.key end)
  return items
end

local function popup(items)
  local lines = {}
  for _, it in ipairs(items) do
    lines[#lines + 1] = string.format(' %-4s %s', it.key, it.desc)
  end
  local width = 12
  for _, l in ipairs(lines) do
    width = math.max(width, #l + 2)
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    anchor = 'SW',
    row = vim.o.lines - vim.o.cmdheight - 1,
    col = 1,
    width = width,
    height = #lines,
    style = 'minimal',
    border = 'rounded',
    focusable = false,
    noautocmd = true,
  })
end

local replaying = false

function M.trigger(leader)
  if replaying then return end
  local keys = leader
  local win
  while true do
    if win then
      pcall(vim.api.nvim_win_close, win, true)
      win = nil
    end
    local items = get_prefixed(keys)
    if #items == 0 then break end
    win = popup(items)
    vim.cmd 'redraw'
    local ok, char = pcall(vim.fn.getcharstr)
    if not ok or char == '\27' then
      if win then pcall(vim.api.nvim_win_close, win, true) end
      return
    end
    keys = keys .. char
  end
  if win then pcall(vim.api.nvim_win_close, win, true) end
  if keys == leader then return end

  replaying = true
  local ok_del = pcall(vim.keymap.del, 'n', leader)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'mtx', false)
  if ok_del then vim.keymap.set('n', leader, function() M.trigger(leader) end, { desc = 'which-key' }) end
  replaying = false
end

function M.setup(leader)
  local literal = vim.api.nvim_replace_termcodes(leader or '<leader>', true, false, true)
  vim.keymap.set('n', literal, function() M.trigger(literal) end, { desc = 'which-key' })
end

return M
