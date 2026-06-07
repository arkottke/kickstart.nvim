vim.pack.add { 'https://github.com/alexghergh/nvim-tmux-navigation' }

local ntv = require('nvim-tmux-navigation')
ntv.setup {}

vim.keymap.set('n', '<C-h>', ntv.NvimTmuxNavigateLeft, { desc = 'Navigate Left' })
vim.keymap.set('n', '<C-j>', ntv.NvimTmuxNavigateDown, { desc = 'Navigate Down' })
vim.keymap.set('n', '<C-k>', ntv.NvimTmuxNavigateUp, { desc = 'Navigate Up' })
vim.keymap.set('n', '<C-l>', ntv.NvimTmuxNavigateRight, { desc = 'Navigate Right' })
vim.keymap.set('n', '<C-\\>', ntv.NvimTmuxNavigateLastActive, { desc = 'Navigate Last Active' })
