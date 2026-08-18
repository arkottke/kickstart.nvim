--[[

Pure-builtin Neovim configuration.

This is a from-scratch replacement for a kickstart.nvim-derived config that
depended on ~25 third-party plugins pulled in via `vim.pack`. Every one of
those has been dropped; everything below is either a genuine Neovim builtin
(the 0.11+ default LSP client, native completion, native diagnostics, native
treesitter, netrw, quickfix, `vim.ui.select`/`vim.ui.input`) or a small
hand-written Lua module under `lua/custom/` that wraps builtin APIs (and, for
git and search, the `git`/`rg`/`fd` CLIs already on $PATH) to approximate a
plugin's UX under the *same keymaps* as before. See CLAUDE.md for the
plugin -> replacement mapping and known gaps.

No plugin manager, no lockfile, no auto-install: LSP servers and CLI
formatters must be installed via your system package manager and be on
$PATH.
--]]

-- ============================================================
-- SECTION 1: FOUNDATION
-- Core Neovim settings, leaders, options, basic keymaps, basic autocmds
-- ============================================================
do
  vim.loader.enable()

  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '

  if vim.fn.has 'windows' == 1 then vim.opt.guifont = 'FiraCode Nerd Font Mono:h9' end

  vim.g.have_nerd_font = true

  vim.o.number = true
  vim.o.mouse = 'a'
  vim.o.showmode = false
  vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)
  vim.o.breakindent = true
  vim.o.undofile = true
  vim.o.ignorecase = true
  vim.o.smartcase = true
  vim.o.signcolumn = 'yes'
  vim.o.updatetime = 250
  vim.o.timeoutlen = 300
  vim.o.splitright = true
  vim.o.splitbelow = true
  vim.o.list = true
  vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
  vim.o.inccommand = 'split'
  vim.o.cursorline = true
  vim.o.scrolloff = 10
  vim.o.confirm = true

  -- [[ Basic Keymaps ]]
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = { severity = { min = vim.diagnostic.severity.WARN } },
    virtual_text = true,
    virtual_lines = false,
    jump = {
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float {
          bufnr = bufnr,
          scope = 'cursor',
          focus = false,
        }
      end,
    },
  }

  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- Keybinds to make split navigation easier (overridden with tmux-aware
  -- versions by custom.tmux_nav in Section 8, same as the original).
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function() vim.hl.on_yank() end,
  })
end

-- ============================================================
-- SECTION 2: UI
-- Colorscheme, netrw, statusline, todo highlighting -- all builtin
-- ============================================================
do
  -- Builtin colorscheme (ships with Neovim). Other reasonable builtin picks:
  -- 'retrobox', 'unokai', 'slate'.
  vim.cmd.colorscheme 'habamax'

  -- [[ netrw as the file explorer ]]
  -- Replaces oil.nvim. `-` opens the parent directory, same as before;
  -- netrw's own `-` (once inside the explorer) goes up a directory.
  vim.g.netrw_banner = 0
  vim.g.netrw_liststyle = 3
  vim.g.netrw_winsize = 25
  vim.keymap.set('n', '-', '<cmd>Explore<CR>', { desc = 'Open parent directory' })

  require('custom.statusline').setup()
  require('custom.todo_highlight').setup()
end

-- ============================================================
-- SECTION 3: SEARCH & NAVIGATION
-- grep/wildmenu setup, vim.ui.select-based pickers (see lua/custom/pickers.lua)
-- ============================================================
do
  require('custom.pickers').setup()
end

-- ============================================================
-- SECTION 4: LSP
-- Native vim.lsp client. Most grr/gri/gO/grt/gra/grn keymaps are already
-- Neovim >=0.11 defaults (see :help lsp-defaults); only the gaps are added.
-- ============================================================
do
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('custom-lsp-attach', { clear = true }),
    callback = function(event)
      local map = function(keys, func, desc, mode)
        mode = mode or 'n'
        vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
      end

      -- Not covered by the builtin defaults:
      map('grd', vim.lsp.buf.definition, '[G]oto [D]efinition')
      map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
      map('gW', function() vim.lsp.buf.workspace_symbol(vim.fn.input 'Workspace symbol query: ') end, 'Open [W]orkspace Symbols')

      local client = vim.lsp.get_client_by_id(event.data.client_id)

      if client and client:supports_method('textDocument/completion', event.buf) then
        vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
      end

      if client and client:supports_method('textDocument/documentHighlight', event.buf) then
        local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.document_highlight,
        })

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.clear_references,
        })

        vim.api.nvim_create_autocmd('LspDetach', {
          group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
          callback = function(event2)
            vim.lsp.buf.clear_references()
            vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
          end,
        })
      end

      if client and client:supports_method('textDocument/inlayHint', event.buf) then
        map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
      end
    end,
  })

  -- No nvim-lspconfig, so each server needs its full cmd/filetypes/root_markers
  -- spelled out (nvim-lspconfig used to supply these as defaults).
  ---@type table<string, vim.lsp.Config>
  local servers = {
    lua_ls = {
      cmd = { 'lua-language-server' },
      filetypes = { 'lua' },
      root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
      on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false -- formatting is done by stylua, see custom.format

        if client.workspace_folders then
          local path = client.workspace_folders[1].name
          if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
        end

        client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
          runtime = { version = 'LuaJIT', path = { 'lua/?.lua', 'lua/?/init.lua' } },
          workspace = {
            checkThirdParty = false,
            library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
              '${3rd}/luv/library',
              '${3rd}/busted/library',
            }),
          },
        })
      end,
      settings = { Lua = { format = { enable = false } } },
    },
    pyright = {
      cmd = { 'pyright-langserver', '--stdio' },
      filetypes = { 'python' },
      root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', 'Pipfile', 'pyrightconfig.json', '.git' },
    },
  }

  for name, cfg in pairs(servers) do
    vim.lsp.config(name, cfg)
    vim.lsp.enable(name)
  end
end

-- ============================================================
-- SECTION 5: FORMATTING
-- ============================================================
do
  require('custom.format').setup()
end

-- ============================================================
-- SECTION 6: COMPLETION & SNIPPETS
-- Native vim.lsp.completion (enabled per-buffer in Section 4) + vim.snippet
-- ============================================================
do
  vim.o.completeopt = 'menuone,noselect'

  -- <C-y>/<C-e>/<C-n>/<C-p> accept/cancel/navigate are already builtin
  -- ins-completion defaults; only the manual trigger and snippet-jump keys
  -- need adding.
  vim.keymap.set('i', '<C-space>', function() require('vim.lsp.completion').get() end, { desc = 'Trigger completion' })

  local function snippet_jump(dir)
    return function()
      if vim.snippet.active { direction = dir } then
        vim.snippet.jump(dir)
      else
        local key = dir > 0 and '<Tab>' or '<S-Tab>'
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), 'n', false)
      end
    end
  end

  vim.keymap.set({ 'i', 's' }, '<Tab>', snippet_jump(1), { desc = 'Snippet forward / Tab' })
  vim.keymap.set({ 'i', 's' }, '<S-Tab>', snippet_jump(-1), { desc = 'Snippet backward / S-Tab' })
end

-- ============================================================
-- SECTION 7: TREESITTER
-- Only languages with a parser already bundled with this Neovim build will
-- highlight (see `:lua =vim.api.nvim_get_runtime_file('parser/*.so', true)`);
-- there is no auto-installer without the nvim-treesitter plugin. Folding is
-- fully builtin now (`vim.treesitter.foldexpr`), unlike in the original.
-- ============================================================
do
  vim.o.foldmethod = 'expr'
  vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  vim.o.foldlevel = 99

  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local lang = vim.treesitter.language.get_lang(args.match) or args.match
      if not pcall(vim.treesitter.language.add, lang) then return end
      pcall(vim.treesitter.start, args.buf, lang)
    end,
  })
end

-- ============================================================
-- SECTION 8: EDITING ENHANCEMENTS
-- Hand-rolled replacements for mini.surround, leap.nvim, which-key.nvim,
-- gitsigns.nvim and nvim-tmux-navigation -- see lua/custom/*.lua
-- ============================================================
do
  require('custom.surround').setup()
  require('custom.leap').setup()
  require('custom.whichkey').setup()
  require('custom.gitsigns').setup()
  require('custom.tmux_nav').setup()
end

-- ============================================================
-- SECTION 9: CUSTOM
-- ============================================================
do
  require 'custom.keymaps'
end

-- vim: ts=2 sts=2 sw=2 et
