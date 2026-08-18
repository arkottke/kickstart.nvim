-- Builtin replacement for todo-comments.nvim: highlight-only, via matchadd().

local M = {}

local keywords = {
  TODO = 'CustomTodo',
  FIXME = 'CustomTodoError',
  BUG = 'CustomTodoError',
  HACK = 'CustomTodoWarn',
  WARN = 'CustomTodoWarn',
  WARNING = 'CustomTodoWarn',
  NOTE = 'CustomTodo',
  PERF = 'CustomTodo',
}

local function apply()
  vim.fn.clearmatches()
  for word, hl in pairs(keywords) do
    vim.fn.matchadd(hl, '\\v<' .. word .. '>:?')
  end
end

function M.setup()
  vim.api.nvim_set_hl(0, 'CustomTodo', { fg = '#1e1e2e', bg = '#89b4fa', bold = true, default = true })
  vim.api.nvim_set_hl(0, 'CustomTodoWarn', { fg = '#1e1e2e', bg = '#f9e2af', bold = true, default = true })
  vim.api.nvim_set_hl(0, 'CustomTodoError', { fg = '#1e1e2e', bg = '#f38ba8', bold = true, default = true })

  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'BufWritePost' }, {
    group = vim.api.nvim_create_augroup('custom-todo-highlight', { clear = true }),
    callback = function(args)
      if vim.bo[args.buf].buftype ~= '' then return end
      apply()
    end,
  })
end

return M
