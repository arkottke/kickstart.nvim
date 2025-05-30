-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'renerocksai/telekasten.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    config = function()
      require('telekasten').setup {
        home = vim.fn.expand 'C:/Users/arkk/zettelkasten',
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
    end,
  },
  {
    'ggandor/leap.nvim',
    config = function()
      require('leap').create_default_mappings()
    end,
    -- `cond` is a condition used to determine whether this plugin should be
    -- installed and loaded.
    -- cond = function()
    --   return vim.fn.has 'linux' == 1
    -- end,
  },
  {
    'lervag/vimtex',
    lazy = false, -- we don't want to lazy load VimTeX
    -- tag = "v2.15", -- uncomment to pin to a specific release
    init = function()
      -- VimTeX configuration goes here, e.g.
      vim.g.vimtex_view_method = 'zathura'
    end,
    cond = function()
      return (vim.fn.executable 'pdflatex' == 1) and (vim.fn.has 'linux' == 1)
    end,
  },
  {
    'alexghergh/nvim-tmux-navigation',
    opts = {
      keybindings = {
        left = '<C-h>',
        down = '<C-j>',
        up = '<C-k>',
        right = '<C-l>',
        last_active = '<C-\\>',
        next = '<C-Space>',
      },
    },
    cond = function()
      return (vim.fn.executable 'make' == 1) and (vim.fn.has 'linux' == 1)
    end,
  },
  { 'catppuccin/nvim', name = 'catppuccin', priority = 1000 },
  {
    'github/copilot.vim',
  },
  {
    'axieax/urlview.nvim',
  },
}
