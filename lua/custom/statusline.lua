-- Builtin replacement for mini.statusline: pure `statusline` option + Lua functions.

local M = {}

local git_branch_cache = {}

local function update_git_branch(cwd)
  if git_branch_cache[cwd] ~= nil then return end
  git_branch_cache[cwd] = false
  vim.system({ 'git', 'branch', '--show-current' }, { cwd = cwd, text = true }, function(res)
    local branch = res.code == 0 and vim.trim(res.stdout or '') or ''
    git_branch_cache[cwd] = branch ~= '' and branch or false
    vim.schedule(function() pcall(vim.cmd.redrawstatus) end)
  end)
end

local mode_names = {
  n = 'NORMAL',
  no = 'O-PENDING',
  i = 'INSERT',
  v = 'VISUAL',
  V = 'V-LINE',
  ['\22'] = 'V-BLOCK',
  c = 'COMMAND',
  R = 'REPLACE',
  t = 'TERMINAL',
  s = 'SELECT',
  S = 'S-LINE',
}

function M.mode() return mode_names[vim.fn.mode()] or vim.fn.mode() end

function M.git_branch()
  local cwd = vim.fn.getcwd()
  update_git_branch(cwd)
  local branch = git_branch_cache[cwd]
  return branch and ('  ' .. branch) or ''
end

local severity_labels = {
  [vim.diagnostic.severity.ERROR] = 'E',
  [vim.diagnostic.severity.WARN] = 'W',
  [vim.diagnostic.severity.INFO] = 'I',
  [vim.diagnostic.severity.HINT] = 'H',
}

function M.diagnostics()
  local ok, counts = pcall(vim.diagnostic.count, 0)
  if not ok then return '' end
  local parts = {}
  for sev, label in pairs(severity_labels) do
    local n = counts[sev]
    if n and n > 0 then table.insert(parts, label .. n) end
  end
  table.sort(parts)
  return #parts > 0 and (' ' .. table.concat(parts, ' ')) or ''
end

function M.active()
  return table.concat {
    ' %{%v:lua.require("custom.statusline").mode()%} ',
    '%{%v:lua.require("custom.statusline").git_branch()%} ',
    '%f %h%m%r',
    '%{%v:lua.require("custom.statusline").diagnostics()%}',
    '%=',
    '%y ',
    '%2l:%-2v ',
  }
end

function M.setup()
  vim.o.laststatus = 3
  vim.o.statusline = '%!v:lua.require("custom.statusline").active()'
end

return M
