-- Builtin replacement for nvim-tmux-navigation: shells out to `tmux` at
-- window edges so <C-hjkl> crosses seamlessly between nvim splits and tmux
-- panes.

local M = {}

local tmux_dir = { h = 'L', j = 'D', k = 'U', l = 'R' }

local function in_tmux() return vim.env.TMUX ~= nil end

local function at_edge(dir)
  local before = vim.api.nvim_get_current_win()
  vim.cmd('wincmd ' .. dir)
  local moved = vim.api.nvim_get_current_win() ~= before
  if moved then vim.api.nvim_set_current_win(before) end
  return not moved
end

function M.navigate(dir)
  if in_tmux() and at_edge(dir) then
    vim.system({ 'tmux', 'select-pane', '-' .. tmux_dir[dir] }):wait()
    return
  end
  vim.cmd('wincmd ' .. dir)
end

function M.navigate_last()
  if in_tmux() then vim.system({ 'tmux', 'select-pane', '-l' }):wait() end
end

function M.setup()
  vim.keymap.set('n', '<C-h>', function() M.navigate 'h' end, { desc = 'Navigate Left' })
  vim.keymap.set('n', '<C-j>', function() M.navigate 'j' end, { desc = 'Navigate Down' })
  vim.keymap.set('n', '<C-k>', function() M.navigate 'k' end, { desc = 'Navigate Up' })
  vim.keymap.set('n', '<C-l>', function() M.navigate 'l' end, { desc = 'Navigate Right' })
  vim.keymap.set('n', '<C-\\>', M.navigate_last, { desc = 'Navigate Last Active' })
end

return M
