if not vim.tbl_contains({ 'bubo', 'falco' }, vim.fn.hostname()) then return end

vim.pack.add {
  'https://github.com/olimorris/codecompanion.nvim',
  'https://github.com/nvim-lua/plenary.nvim',
}

-- Ollama model tag must already be pulled locally: `ollama pull devstral-small-2:24b`
local ollama_model = 'devstral-small-2:24b'

require('codecompanion').setup {
  adapters = {
    http = {
      anthropic = function()
        return require('codecompanion.adapters').extend('anthropic', {
          env = { api_key = 'ANTHROPIC_API_KEY' },
        })
      end,
      ollama = function()
        return require('codecompanion.adapters').extend('ollama', {
          schema = { model = { default = ollama_model } },
        })
      end,
    },
  },
  interactions = {
    chat = { adapter = { name = 'ollama', model = ollama_model } },
    inline = { adapter = { name = 'ollama', model = ollama_model } },
  },
  display = {
    chat = { show_settings = true },
  },
}

vim.keymap.set({ 'n', 'v' }, '<leader>ac', '<cmd>CodeCompanionChat Toggle<cr>', { desc = '[A]I [C]hat toggle' })
vim.keymap.set({ 'n', 'v' }, '<leader>aa', '<cmd>CodeCompanionActions<cr>', { desc = '[A]I [A]ctions' })
vim.keymap.set('v', '<leader>ai', '<cmd>CodeCompanion<cr>', { desc = '[A]I [I]nline' })
vim.keymap.set('n', '<leader>an', '<cmd>CodeCompanionChat<cr>', { desc = '[A]I [N]ew chat' })

-- Toggles the default adapter used for *new* chats/inline requests between
-- Anthropic and the local Ollama model. Existing chat buffers are unaffected;
-- use the plugin's own `ga` keymap inside a chat to change its adapter.
local cc_adapters = {
  anthropic = 'anthropic',
  ollama = { name = 'ollama', model = ollama_model },
}
local cc_current = 'ollama'

vim.keymap.set('n', '<leader>at', function()
  cc_current = (cc_current == 'anthropic') and 'ollama' or 'anthropic'
  local adapter = cc_adapters[cc_current]
  local cc_config = require('codecompanion.config').config
  cc_config.interactions.chat.adapter = adapter
  cc_config.interactions.inline.adapter = adapter
  vim.notify('CodeCompanion adapter: ' .. cc_current, vim.log.levels.INFO, { title = 'CodeCompanion' })
end, { desc = '[A]I [T]oggle adapter (anthropic/ollama)' })
