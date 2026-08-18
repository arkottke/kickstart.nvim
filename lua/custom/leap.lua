-- Compact approximation of leap.nvim's `s`/`S` motion using only builtin
-- APIs: getcharstr() to read the 2-char search + label choice, and extmarks
-- to overlay jump labels. Searches the visible portion of the window(s).

local M = {}

local ns = vim.api.nvim_create_namespace 'custom_leap'
local label_chars = 'asdfghjklqwertyuiopzxcvbnm'

local function clear(bufnr) pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, 0, -1) end

local function visible_range(win) return vim.fn.line('w0', win), vim.fn.line('w$', win) end

function M.leap(target_win)
  target_win = target_win or vim.api.nvim_get_current_win()
  local prev_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(target_win)

  local ok1, c1 = pcall(vim.fn.getcharstr)
  if not ok1 or c1 == '\27' then return end
  local ok2, c2 = pcall(vim.fn.getcharstr)
  if not ok2 or c2 == '\27' then return end

  local needle = c1 .. c2
  local top, bot = visible_range(target_win)
  local bufnr = vim.api.nvim_win_get_buf(target_win)
  local matches = {}
  for lnum = top, bot do
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ''
    local init = 1
    while true do
      local s, e = line:find(needle, init, true)
      if not s then break end
      table.insert(matches, { lnum = lnum, col = s })
      init = e + 1
    end
  end

  if #matches == 0 then
    vim.notify('leap: no matches', vim.log.levels.WARN)
    return
  end

  if #matches == 1 then
    vim.api.nvim_win_set_cursor(target_win, { matches[1].lnum, matches[1].col - 1 })
    return
  end

  local cur = vim.api.nvim_win_get_cursor(target_win)
  table.sort(matches, function(a, b)
    local da = math.abs(a.lnum - cur[1]) * 1000 + math.abs(a.col - cur[2])
    local db = math.abs(b.lnum - cur[1]) * 1000 + math.abs(b.col - cur[2])
    return da < db
  end)
  matches = vim.list_slice(matches, 1, math.min(#matches, #label_chars))

  for i, m in ipairs(matches) do
    vim.api.nvim_buf_set_extmark(bufnr, ns, m.lnum - 1, m.col - 1, {
      virt_text = { { label_chars:sub(i, i), 'IncSearch' } },
      virt_text_pos = 'overlay',
      priority = 200,
    })
  end
  vim.cmd 'redraw'

  local ok3, choice = pcall(vim.fn.getcharstr)
  clear(bufnr)
  if not ok3 then return end

  for i, m in ipairs(matches) do
    if label_chars:sub(i, i) == choice then
      vim.api.nvim_win_set_cursor(target_win, { m.lnum, m.col - 1 })
      return
    end
  end
  vim.api.nvim_set_current_win(prev_win == target_win and target_win or prev_win)
end

function M.leap_from_window()
  local wins = vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == '' end, vim.api.nvim_tabpage_list_wins(0))
  if #wins <= 1 then
    M.leap()
    return
  end

  local win_labels = {}
  for i, w in ipairs(wins) do
    local label = label_chars:sub(i, i)
    win_labels[label] = w
    local buf = vim.api.nvim_win_get_buf(w)
    local top = vim.fn.line('w0', w)
    vim.api.nvim_buf_set_extmark(buf, ns, top - 1, 0, {
      virt_text = { { ' ' .. label .. ' ', 'IncSearch' } },
      virt_text_pos = 'overlay',
    })
  end
  vim.cmd 'redraw'

  local ok, choice = pcall(vim.fn.getcharstr)
  for _, w in ipairs(wins) do
    clear(vim.api.nvim_win_get_buf(w))
  end
  if not ok or not win_labels[choice] then return end
  M.leap(win_labels[choice])
end

function M.setup()
  vim.keymap.set({ 'n', 'x', 'o' }, 's', M.leap, { desc = 'Leap' })
  vim.keymap.set('n', 'S', M.leap_from_window, { desc = 'Leap from window' })
end

return M
