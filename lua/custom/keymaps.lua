-- Maps filetype to the shell command used to run the current file (%s is the quoted file path)
local run_commands = {
  python = 'python3 %s',
  lua = 'lua %s',
  sh = 'bash %s',
  javascript = 'node %s',
  typescript = 'npx tsx %s',
  go = 'go run %s',
}

local function run_current_file()
  local cmd_fmt = run_commands[vim.bo.filetype]
  if not cmd_fmt then
    vim.notify('No run command configured for filetype: ' .. vim.bo.filetype, vim.log.levels.WARN, { title = 'Run file' })
    return
  end
  local file = vim.fn.shellescape(vim.fn.expand '%:p')
  vim.cmd 'botright 15split | terminal'
  vim.fn.chansend(vim.bo.channel, cmd_fmt:format(file) .. '\n')
end

vim.keymap.set('n', '<leader>rr', run_current_file, { desc = '[R]un current file' })
vim.keymap.set('n', '<F5>', run_current_file, { desc = 'Run current file' })
