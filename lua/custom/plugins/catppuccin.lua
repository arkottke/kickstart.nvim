vim.pack.add { { src = 'https://github.com/catppuccin/nvim', name = 'catppuccin' } }

require('catppuccin').setup {
  flavour = 'frappe',
}

vim.cmd.colorscheme 'catppuccin-frappe'
