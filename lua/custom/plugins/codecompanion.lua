if not vim.tbl_contains({ 'bubo', 'falco' }, vim.fn.hostname()) then return end

vim.pack.add {
  'https://github.com/olimorris/codecompanion.nvim',
  'https://github.com/nvim-lua/plenary.nvim',
}

require('codecompanion').setup {
  adapters = {
    anthropic = function()
      return require('codecompanion.adapters').extend('anthropic', {
        env = { api_key = 'ANTHROPIC_API_KEY' },
      })
    end,
  },
  strategies = {
    chat = { adapter = 'anthropic' },
    inline = { adapter = 'anthropic' },
    agent = { adapter = 'anthropic' },
  },
  display = {
    chat = { show_settings = true },
  },
}

vim.keymap.set({ 'n', 'v' }, '<leader>ac', '<cmd>CodeCompanionChat Toggle<cr>', { desc = '[A]I [C]hat toggle' })
vim.keymap.set({ 'n', 'v' }, '<leader>aa', '<cmd>CodeCompanionActions<cr>', { desc = '[A]I [A]ctions' })
vim.keymap.set('v', '<leader>ai', '<cmd>CodeCompanion<cr>', { desc = '[A]I [I]nline' })
vim.keymap.set('n', '<leader>an', '<cmd>CodeCompanionChat<cr>', { desc = '[A]I [N]ew chat' })
