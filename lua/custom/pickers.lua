-- Builtin replacement for the Telescope pickers: vim.ui.select / vim.ui.input
-- plus the quickfix list (populated via getqflist({lines=...}), which parses
-- ripgrep --vimgrep output through 'grepformat' without touching a file).

local M = {}

local function set_qflist(lines, title)
  lines = vim.tbl_filter(function(l) return l ~= '' end, lines)
  if #lines == 0 then
    vim.notify('No matches for: ' .. title, vim.log.levels.WARN)
    return
  end
  local qf = vim.fn.getqflist { lines = lines }
  vim.fn.setqflist({}, ' ', { title = title, items = qf.items })
  vim.cmd.copen()
end

function M.help() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(':help ', true, false, true), 'n', false) end

function M.keymaps()
  local items = {}
  for _, mode in ipairs { 'n', 'i', 'v', 'x' } do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      items[#items + 1] = string.format('[%s] %-18s %s', mode, m.lhs, m.desc or m.rhs or '')
    end
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
      items[#items + 1] = string.format('[%s*] %-17s %s', mode, m.lhs, m.desc or m.rhs or '')
    end
  end
  vim.ui.select(items, { prompt = 'Keymaps:' }, function() end)
end

function M.files(cwd)
  cwd = cwd or vim.fn.getcwd()
  local ok, query = pcall(vim.fn.input, 'Filter (blank for all): ')
  if not ok then return end
  local cmd
  if vim.fn.executable 'fd' == 1 then
    cmd = { 'fd', '--type', 'f', '--hidden', '--exclude', '.git' }
  else
    cmd = { 'rg', '--files', '--hidden', '--glob', '!.git' }
  end
  if query ~= '' then table.insert(cmd, query) end
  local result = vim.system(cmd, { cwd = cwd, text = true }):wait()
  local files = vim.split(vim.trim(result.stdout or ''), '\n', { trimempty = true })
  if #files == 0 then
    vim.notify('No files found', vim.log.levels.WARN)
    return
  end
  if #files > 200 then files = vim.list_slice(files, 1, 200) end
  vim.ui.select(files, { prompt = 'Files:' }, function(choice)
    if choice then vim.cmd.edit(vim.fs.joinpath(cwd, choice)) end
  end)
end

function M.grep(opts)
  opts = opts or {}
  local pattern = opts.pattern
  if not pattern then
    local ok, input = pcall(vim.fn.input, 'Grep: ')
    if not ok or input == '' then return end
    pattern = input
  end
  local cmd = { 'rg', '--vimgrep', '--smart-case', pattern }
  vim.list_extend(cmd, opts.files or {})
  local result = vim.system(cmd, { text = true }):wait()
  set_qflist(vim.split(result.stdout or '', '\n', { trimempty = true }), pattern)
end

function M.grep_word(mode)
  local word
  if mode == 'v' then
    local s = vim.fn.getpos "'<"
    local e = vim.fn.getpos "'>"
    local lines = vim.api.nvim_buf_get_text(0, s[2] - 1, s[3] - 1, e[2] - 1, e[4], {})
    word = table.concat(lines, ' ')
  else
    word = vim.fn.expand '<cword>'
  end
  if word == '' then return end
  M.grep { pattern = word }
end

function M.grep_open_files()
  local files = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted then
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= '' then table.insert(files, name) end
    end
  end
  local ok, input = pcall(vim.fn.input, 'Grep in open files: ')
  if not ok or input == '' then return end
  M.grep { pattern = input, files = files }
end

function M.diagnostics() vim.diagnostic.setqflist { open = true } end

function M.oldfiles()
  local files = vim.tbl_filter(function(f) return vim.fn.filereadable(f) == 1 end, vim.v.oldfiles)
  vim.ui.select(files, { prompt = 'Recent files:' }, function(choice)
    if choice then vim.cmd.edit(choice) end
  end)
end

function M.commands()
  local cmds = vim.fn.getcompletion('', 'command')
  vim.ui.select(cmds, { prompt = 'Command:' }, function(choice)
    if choice then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(':' .. choice .. ' ', true, false, true), 'n', false) end
  end)
end

function M.buffers()
  local bufs = vim.tbl_filter(function(b) return vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted end, vim.api.nvim_list_bufs())
  local items = vim.tbl_map(function(b)
    local name = vim.api.nvim_buf_get_name(b)
    return name ~= '' and vim.fn.fnamemodify(name, ':.') or ('[No Name #' .. b .. ']')
  end, bufs)
  vim.ui.select(items, { prompt = 'Buffers:' }, function(_, idx)
    if idx then vim.api.nvim_set_current_buf(bufs[idx]) end
  end)
end

function M.menu()
  local actions = {
    { 'Help', M.help },
    { 'Keymaps', M.keymaps },
    { 'Files', function() M.files() end },
    { 'Grep', function() M.grep() end },
    { 'Diagnostics', M.diagnostics },
    { 'Recent Files', M.oldfiles },
    { 'Commands', M.commands },
    { 'Buffers', M.buffers },
  }
  vim.ui.select(actions, { prompt = 'Search:', format_item = function(a) return a[1] end }, function(choice)
    if choice then choice[2]() end
  end)
end

function M.setup()
  if vim.fn.executable 'rg' == 1 then
    vim.o.grepprg = 'rg --vimgrep --smart-case --hidden --glob=!.git'
    vim.o.grepformat = '%f:%l:%c:%m'
  end
  vim.o.wildoptions = 'fuzzy'

  vim.keymap.set('n', '<leader>sh', M.help, { desc = '[S]earch [H]elp' })
  vim.keymap.set('n', '<leader>sk', M.keymaps, { desc = '[S]earch [K]eymaps' })
  vim.keymap.set('n', '<leader>sf', function() M.files() end, { desc = '[S]earch [F]iles' })
  vim.keymap.set('n', '<leader>ss', M.menu, { desc = '[S]earch [S]elect' })
  vim.keymap.set('n', '<leader>sw', function() M.grep_word 'n' end, { desc = '[S]earch current [W]ord' })
  vim.keymap.set('v', '<leader>sw', function() M.grep_word 'v' end, { desc = '[S]earch current [W]ord' })
  vim.keymap.set('n', '<leader>sg', function() M.grep() end, { desc = '[S]earch by [G]rep' })
  vim.keymap.set('n', '<leader>sd', M.diagnostics, { desc = '[S]earch [D]iagnostics' })
  vim.keymap.set('n', '<leader>sr', function() pcall(vim.cmd.copen) end, { desc = '[S]earch [R]esume (quickfix)' })
  vim.keymap.set('n', '<leader>s.', M.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
  vim.keymap.set('n', '<leader>sc', M.commands, { desc = '[S]earch [C]ommands' })
  vim.keymap.set('n', '<leader><leader>', M.buffers, { desc = '[ ] Find existing buffers' })
  vim.keymap.set('n', '<leader>/', '/', { desc = '[/] Search in current buffer' })
  vim.keymap.set('n', '<leader>s/', M.grep_open_files, { desc = '[S]earch [/] in Open Files' })
  vim.keymap.set('n', '<leader>sn', function() M.files(vim.fn.stdpath 'config') end, { desc = '[S]earch [N]eovim files' })
end

return M
