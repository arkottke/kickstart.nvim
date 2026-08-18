# nvim (pure-builtin)

A personal Neovim configuration with **zero third-party plugins**. Originally forked from
[kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim), then rewritten to use only Neovim's own builtins (LSP
client, native completion, native diagnostics, native treesitter, netrw, quickfix, `vim.ui.select`) plus a handful
of small hand-written Lua modules under `lua/custom/` that wrap those builtins to approximate what a plugin used to
do, under the same keymaps. No plugin manager, no lockfile, nothing to install beyond Neovim itself.

See `CLAUDE.md` for the architecture and the plugin -> replacement mapping.

## Requirements

- Neovim >= 0.11 (developed against 0.12)
- `git`, `ripgrep` (`rg`), `fd` — used by `lua/custom/pickers.lua` and `lua/custom/gitsigns.lua`
- Optional, for LSP/formatting: `lua-language-server`, `pyright`, `stylua`, `ruff`, `prettier`, `latexindent` on
  `$PATH`

## Install

```sh
git clone <this repo> ~/.config/nvim
nvim
```

Nothing else to install — just launch `nvim`.
