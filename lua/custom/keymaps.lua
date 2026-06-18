vim.keymap.set('n', '<leader>pu', '<cmd>lua vim.pack.update()<CR>', { desc = '[P]lugin [U]pdate' })

vim.keymap.set('n', '<F5>', function()
  local file = vim.fn.expand '%:p'
  vim.cmd 'botright 15split | terminal'
  vim.fn.chansend(vim.bo.channel, 'python ' .. file .. '\n')
end, { desc = 'Run current Python file' })
