-- Compact replacement for mini.surround, using only builtin APIs
-- (operatorfunc, searchpairpos, extmark-free buffer text edits).
--
-- Keymaps (normal unless noted):
--   sa{motion}{char}  add surround               (visual: select, then `sa{char}`)
--   sd{char}          delete surround
--   sr{char}{newchar} replace surround
--
-- Only single-line matching is supported for quote-like characters; bracket
-- pairs ( ) [ ] { } < > use `searchpairpos()` so they work across lines.

local M = {}

local pairs_map = {
  ['('] = { '(', ')' },
  [')'] = { '(', ')' },
  ['['] = { '[', ']' },
  [']'] = { '[', ']' },
  ['{'] = { '{', '}' },
  ['}'] = { '{', '}' },
  ['<'] = { '<', '>' },
  ['>'] = { '<', '>' },
}

local function get_pair(char)
  local p = pairs_map[char]
  if p then return p[1], p[2] end
  return char, char
end

local function get_char(prompt)
  vim.cmd.redraw()
  vim.api.nvim_echo({ { prompt, 'Question' } }, false, {})
  local ok, c = pcall(vim.fn.getcharstr)
  vim.api.nvim_echo({ { '', '' } }, false, {})
  if not ok or c == '\27' then return nil end
  return c
end

local function wrap_range(srow, scol, erow, ecol, open, close)
  vim.api.nvim_buf_set_text(0, erow, ecol, erow, ecol, { close })
  vim.api.nvim_buf_set_text(0, srow, scol, srow, scol, { open })
end

function M.add_visual()
  local char = get_char 'Surround with: '
  if not char then return end
  local open, close = get_pair(char)
  local srow, scol = unpack(vim.fn.getpos "'<", 2)
  local erow, ecol = unpack(vim.fn.getpos "'>", 2)
  wrap_range(srow - 1, scol - 1, erow - 1, ecol, open, close)
end

function M.add_operator(motion_type)
  local srow, scol = unpack(vim.fn.getpos "'[", 2)
  local erow, ecol = unpack(vim.fn.getpos "']", 2)
  local char = get_char 'Surround with: '
  if not char then return end
  local open, close = get_pair(char)
  if motion_type == 'line' then
    vim.api.nvim_buf_set_lines(0, erow, erow, false, { close })
    vim.api.nvim_buf_set_lines(0, srow - 1, srow - 1, false, { open })
  else
    wrap_range(srow - 1, scol - 1, erow - 1, ecol, open, close)
  end
end

function M.add_normal()
  vim.o.operatorfunc = "v:lua.require'custom.surround'.add_operator"
  vim.api.nvim_feedkeys('g@', 'n', false)
end

local function find_surround_bracket(open, close)
  local o_esc, c_esc = vim.fn.escape(open, '\\[].*$~'), vim.fn.escape(close, '\\[].*$~')
  local save = vim.fn.getcurpos()
  local oline, ocol = unpack(vim.fn.searchpairpos(o_esc, '', c_esc, 'bnW'))
  vim.fn.setpos('.', save)
  local cline, ccol = unpack(vim.fn.searchpairpos(o_esc, '', c_esc, 'nW'))
  vim.fn.setpos('.', save)
  if oline == 0 or cline == 0 then return nil end
  return oline, ocol, cline, ccol
end

local function find_surround_same_line(char)
  local lnum = vim.fn.line '.'
  local line = vim.fn.getline(lnum)
  local col = vim.fn.col '.'
  local positions = {}
  for i = 1, #line do
    if line:sub(i, i) == char then positions[#positions + 1] = i end
  end
  for i = 1, #positions - 1, 2 do
    local a, b = positions[i], positions[i + 1]
    if a <= col and col <= b then return lnum, a, lnum, b end
  end
  return nil
end

local function find_surround(char)
  local open, close = get_pair(char)
  if open ~= close then return find_surround_bracket(open, close) end
  return find_surround_same_line(char)
end

function M.delete()
  local char = get_char 'Delete surround: '
  if not char then return end
  local oline, ocol, cline, ccol = find_surround(char)
  if not oline then
    vim.notify('surround: not found', vim.log.levels.WARN)
    return
  end
  vim.api.nvim_buf_set_text(0, cline - 1, ccol - 1, cline - 1, ccol, {})
  vim.api.nvim_buf_set_text(0, oline - 1, ocol - 1, oline - 1, ocol, {})
end

function M.replace()
  local char = get_char 'Replace surround: '
  if not char then return end
  local oline, ocol, cline, ccol = find_surround(char)
  if not oline then
    vim.notify('surround: not found', vim.log.levels.WARN)
    return
  end
  local newchar = get_char 'Replace with: '
  if not newchar then return end
  local open, close = get_pair(newchar)
  vim.api.nvim_buf_set_text(0, cline - 1, ccol - 1, cline - 1, ccol, { close })
  vim.api.nvim_buf_set_text(0, oline - 1, ocol - 1, oline - 1, ocol, { open })
end

function M.setup()
  vim.keymap.set('n', 'sa', M.add_normal, { desc = 'Surround add' })
  vim.keymap.set('x', 'sa', M.add_visual, { desc = 'Surround add' })
  vim.keymap.set('n', 'sd', M.delete, { desc = 'Surround delete' })
  vim.keymap.set('n', 'sr', M.replace, { desc = 'Surround replace' })
end

return M
