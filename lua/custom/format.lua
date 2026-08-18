-- Builtin replacement for conform.nvim: LSP formatting by default, with a
-- couple of external formatters run via vim.system() for filetypes where an
-- LSP formatter isn't the right tool (matches the original formatters_by_ft).

local M = {}

local formatters_by_ft = {
  python = function(name)
    return {
      { 'ruff', 'check', '--fix', '--select', 'I', '--stdin-filename', name, '-' },
      { 'ruff', 'format', '--stdin-filename', name, '-' },
    }
  end,
  markdown = function() return { { 'prettier', '--parser', 'markdown' } } end,
  tex = function() return { { 'latexindent' } } end,
}

local function run_external(bufnr, cmds)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local input = table.concat(lines, '\n') .. '\n'
  for _, cmd in ipairs(cmds) do
    if vim.fn.executable(cmd[1]) == 0 then return nil end
    local result = vim.system(cmd, { stdin = input }):wait()
    if result.code ~= 0 then
      vim.notify(('Format failed (%s): %s'):format(cmd[1], result.stderr or ''), vim.log.levels.ERROR)
      return nil
    end
    input = result.stdout or input
  end
  return vim.split((input:gsub('\n$', '')), '\n')
end

function M.format(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local builder = formatters_by_ft[ft]
  if builder then
    local new_lines = run_external(bufnr, builder(vim.api.nvim_buf_get_name(bufnr)))
    if new_lines then
      local view = vim.fn.winsaveview()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
      vim.fn.winrestview(view)
      return
    end
  end
  vim.lsp.buf.format { bufnr = bufnr, async = true }
end

function M.setup()
  vim.keymap.set({ 'n', 'v' }, '<leader>f', function() M.format() end, { desc = '[F]ormat buffer' })
end

return M
