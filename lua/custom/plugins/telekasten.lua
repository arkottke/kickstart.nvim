vim.pack.add {
  'https://github.com/renerocksai/telekasten.nvim',
  'https://github.com/nvim-telescope/telescope.nvim',
}

require('telekasten').setup {
  home = vim.fn.expand '~/zettelkasten',
}

-- Launch panel if nothing is typed after <leader>n
vim.keymap.set('n', '<leader>n', '<cmd>Telekasten panel<CR>')

-- Most used functions
vim.keymap.set('n', '<leader>nf', '<cmd>Telekasten find_notes<CR>')
vim.keymap.set('n', '<leader>ng', '<cmd>Telekasten search_notes<CR>')
vim.keymap.set('n', '<leader>nw', '<cmd>Telekasten goto_thisweek<CR>')
vim.keymap.set('n', '<leader>nz', '<cmd>Telekasten follow_link<CR>')
vim.keymap.set('n', '<leader>nn', '<cmd>Telekasten new_note<CR>')
vim.keymap.set('n', '<leader>nc', '<cmd>Telekasten show_calendar<CR>')
vim.keymap.set('n', '<leader>nb', '<cmd>Telekasten show_backlinks<CR>')
vim.keymap.set('n', '<leader>nI', '<cmd>Telekasten insert_img_link<CR>')

vim.keymap.set('n', '<leader>nt', '<cmd>Telekasten toggle_todo<CR>')
vim.keymap.set('v', '<leader>nt', ':Telekasten toggle_todo<CR>')

-- Call insert link automatically when we start typing a link
vim.keymap.set('i', '[[', '<cmd>Telekasten insert_link<CR>')
