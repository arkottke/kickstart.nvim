# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal Neovim configuration forked from [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) — a single-file, well-documented starting point. The upstream is tracked as `upstream/master`.

Plugin management uses **`vim.pack`**, Neovim's built-in plugin manager (not lazy.nvim). Plugins are installed on first launch and updated via `:lua vim.pack.update()`.

## Formatting

All Lua files must be formatted with **StyLua** before committing. The `.stylua.toml` config specifies:
- 160-column width, 2-space indent, single quotes, always-collapse simple statements

Check formatting: `stylua --check .`  
Fix formatting: `stylua .`

The CI workflow (`.github/workflows/stylua.yml`) enforces this on PRs to the upstream repo.

## Architecture

### Entry point

`init.lua` is the single configuration file, organized into 9 numbered `do...end` blocks:

1. **Foundation** — options, leader key, keymaps, autocmds, diagnostics
2. **Plugin Manager** — `vim.pack` setup and `PackChanged` build hooks (telescope-fzf-native, LuaSnip, nvim-treesitter)
3. **UI/Core UX** — guess-indent, gitsigns, which-key, tokyonight colorscheme, todo-comments, mini.nvim (ai, surround, statusline)
4. **Search & Navigation** — Telescope with fzf-native, ui-select; LSP picker keymaps registered on `LspAttach`
5. **LSP** — fidget, nvim-lspconfig, Mason + mason-lspconfig + mason-tool-installer; active servers: `lua_ls` (with stylua formatting disabled) and `stylua`
6. **Formatting** — conform.nvim with `<leader>f`; format-on-save is disabled by default (enable per-filetype in `enabled_filetypes`)
7. **Autocomplete & Snippets** — blink.cmp (v1.*) + LuaSnip (v2.*) with `default` keymap preset
8. **Treesitter** — nvim-treesitter on `main` branch; parsers auto-install on `FileType` event
9. **Optional/Custom** — loads `kickstart.plugins.gitsigns` and all files under `lua/custom/plugins/`

### Custom plugins (`lua/custom/plugins/`)

`init.lua` auto-loads every `*.lua` file in this directory (except itself). Current plugins:

| File | Plugin | Purpose |
|---|---|---|
| `catppuccin.lua` | catppuccin/nvim | Alternative colorscheme |
| `copilot.lua` | copilot.lua + copilot-lsp + blink-cmp-copilot | GitHub Copilot via blink.cmp |
| `leap.lua` | leap.nvim | Motion with `s`/`S` |
| `nvim-tmux-navigation.lua` | nvim-tmux-navigation | `<C-hjkl>` across nvim+tmux panes |
| `telekasten.lua` | telekasten.nvim | Zettelkasten notes at `~/zettelkasten`; `<leader>n` prefix |
| `urlview.lua` | urlview.nvim | URL extraction/navigation |
| `vimtex.lua` | vimtex | LaTeX editing |

### Kickstart optional plugins (`lua/kickstart/plugins/`)

Pre-written optional modules (most are commented out in init.lua): `autopairs`, `debug`, `gitsigns` (keymaps), `indent_line`, `lint`, `neo-tree`. Only `gitsigns` is currently active.

## Key conventions

- **Leader**: `<Space>`; **LocalLeader**: `<Space>`
- Adding a plugin: call `vim.pack.add { 'https://github.com/...' }` then `require('plugin').setup({})`; place custom plugins in `lua/custom/plugins/<name>.lua`
- Build hooks for new plugins that need a post-install step go in the `PackChanged` autocmd in Section 2 of `init.lua`
- LSP servers are configured in the `servers` table in Section 5; Mason installs them automatically
- The `gh()` helper shortens GitHub URLs: `gh 'owner/repo'` → `'https://github.com/owner/repo'`
