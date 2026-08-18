-- Compact replacement for gitsigns.nvim: shells out to the `git` CLI and
-- renders hunks with extmarks. Covers the common hunk/buffer stage & reset,
-- preview, blame, diff, and navigation workflows; word-diff toggling and
-- repo-wide quickfix lists from the original are not reimplemented.

local M = {}

local ns = vim.api.nvim_create_namespace 'custom_gitsigns'
local blame_ns = vim.api.nvim_create_namespace 'custom_gitsigns_blame'
local state = {} -- bufnr -> { hunks, root, rel }
local blame_enabled = {}
local roots = {} -- dir -> repo root (or false)

local function git_root(dir)
  if roots[dir] ~= nil then return roots[dir] or nil end
  local r = vim.system({ 'git', '-C', dir, 'rev-parse', '--show-toplevel' }, { text = true }):wait()
  local root = r.code == 0 and vim.trim(r.stdout or '') or false
  roots[dir] = root
  return root or nil
end

local function parse_diff(output)
  local hunks, cur = {}, nil
  for _, line in ipairs(output) do
    local os_, oc, ns_, nc = line:match '^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@'
    if os_ then
      cur = {
        old_start = tonumber(os_),
        old_count = oc ~= '' and tonumber(oc) or 1,
        new_start = tonumber(ns_),
        new_count = nc ~= '' and tonumber(nc) or 1,
        lines = { line },
      }
      table.insert(hunks, cur)
    elseif cur and (line:sub(1, 1) == '+' or line:sub(1, 1) == '-') then
      table.insert(cur.lines, line)
    end
  end
  return hunks
end

local function hunk_range(h)
  if h.new_count == 0 then return h.new_start, h.new_start end
  return h.new_start, h.new_start + h.new_count - 1
end

local function clear_signs(bufnr) pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, 0, -1) end

local function place_signs(bufnr, hunks)
  clear_signs(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for _, h in ipairs(hunks) do
    if h.old_count == 0 then
      for row = h.new_start, h.new_start + h.new_count - 1 do
        if row >= 1 and row <= line_count then
          pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row - 1, 0, { sign_text = '+', sign_hl_group = 'GitSignsAdd' })
        end
      end
    elseif h.new_count == 0 then
      local row = math.max(1, math.min(h.new_start, line_count))
      pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row - 1, 0, { sign_text = '_', sign_hl_group = 'GitSignsDelete' })
    else
      for row = h.new_start, h.new_start + h.new_count - 1 do
        if row >= 1 and row <= line_count then
          pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row - 1, 0, { sign_text = '~', sign_hl_group = 'GitSignsChange' })
        end
      end
    end
  end
end

function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' or vim.bo[bufnr].buftype ~= '' then return end
  local dir = vim.fn.fnamemodify(name, ':h')
  local root = git_root(dir)
  if not root then
    state[bufnr] = nil
    clear_signs(bufnr)
    return
  end
  vim.system({ 'git', '-C', dir, 'diff', '--no-color', '--no-ext-diff', '-U0', '--', name }, { text = true }, function(res)
    if res.code ~= 0 then return end
    local hunks = parse_diff(vim.split(res.stdout or '', '\n'))
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then return end
      state[bufnr] = { hunks = hunks, root = root, rel = name:sub(#root + 2) }
      place_signs(bufnr, hunks)
    end)
  end)
end

local timers = {}
local function schedule_refresh(bufnr)
  if timers[bufnr] then pcall(function() timers[bufnr]:stop() end) end
  timers[bufnr] = vim.defer_fn(function() M.refresh(bufnr) end, 300)
end

local function hunk_under_cursor(bufnr)
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  for _, h in ipairs((state[bufnr] or {}).hunks or {}) do
    local s, e = hunk_range(h)
    if lnum >= s and lnum <= e then return h end
  end
  return nil
end

function M.nav_hunk(dir)
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local rows = {}
  for _, h in ipairs((state[bufnr] or {}).hunks or {}) do
    table.insert(rows, (hunk_range(h)))
  end
  if #rows == 0 then return end
  table.sort(rows)
  local target
  if dir == 'next' then
    for _, row in ipairs(rows) do
      if row > lnum then
        target = row
        break
      end
    end
    target = target or rows[1]
  else
    for i = #rows, 1, -1 do
      if rows[i] < lnum then
        target = rows[i]
        break
      end
    end
    target = target or rows[#rows]
  end
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

local function build_patch(rel, h)
  local lines = { ('diff --git a/%s b/%s'):format(rel, rel), ('--- a/%s'):format(rel), ('+++ b/%s'):format(rel) }
  vim.list_extend(lines, h.lines)
  return table.concat(lines, '\n') .. '\n'
end

local function old_lines_of(h)
  local lines = {}
  for _, l in ipairs(h.lines) do
    if l:sub(1, 1) == '-' then table.insert(lines, l:sub(2)) end
  end
  return lines
end

function M.stage_hunk()
  local bufnr = vim.api.nvim_get_current_buf()
  local st = state[bufnr]
  local h = st and hunk_under_cursor(bufnr)
  if not h then
    vim.notify('No hunk under cursor', vim.log.levels.WARN)
    return
  end
  local res = vim.system({ 'git', 'apply', '--cached', '--unidiff-zero', '-' }, { cwd = st.root, stdin = build_patch(st.rel, h) }):wait()
  if res.code ~= 0 then
    vim.notify('git apply failed: ' .. (res.stderr or ''), vim.log.levels.ERROR)
    return
  end
  M.refresh(bufnr)
end

function M.reset_hunk()
  local bufnr = vim.api.nvim_get_current_buf()
  local st = state[bufnr]
  local h = st and hunk_under_cursor(bufnr)
  if not h then
    vim.notify('No hunk under cursor', vim.log.levels.WARN)
    return
  end
  local old = old_lines_of(h)
  local start_row, end_row
  if h.new_count == 0 then
    start_row, end_row = h.new_start, h.new_start
  else
    start_row, end_row = h.new_start - 1, h.new_start - 1 + h.new_count
  end
  vim.api.nvim_buf_set_lines(bufnr, start_row, end_row, false, old)
  M.refresh(bufnr)
end

function M.stage_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.cmd 'write'
  local name = vim.api.nvim_buf_get_name(bufnr)
  vim.system({ 'git', 'add', '--', name }, { cwd = vim.fn.fnamemodify(name, ':h') }):wait()
  M.refresh(bufnr)
end

function M.reset_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  vim.system({ 'git', 'checkout', '--', name }, { cwd = vim.fn.fnamemodify(name, ':h') }):wait()
  vim.cmd 'edit!'
  M.refresh(bufnr)
end

function M.preview_hunk()
  local bufnr = vim.api.nvim_get_current_buf()
  local h = hunk_under_cursor(bufnr)
  if not h then
    vim.notify('No hunk under cursor', vim.log.levels.WARN)
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, h.lines)
  vim.bo[buf].filetype = 'diff'
  vim.api.nvim_open_win(buf, false, {
    relative = 'cursor',
    row = 1,
    col = 0,
    width = math.min(90, vim.o.columns - 4),
    height = math.min(#h.lines, 15),
    style = 'minimal',
    border = 'rounded',
  })
end

function M.blame_line()
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then return end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local res = vim
    .system({ 'git', 'blame', '-L', lnum .. ',' .. lnum, '--date=short', '--', name }, {
      cwd = vim.fn.fnamemodify(name, ':h'),
      text = true,
    })
    :wait()
  if res.code ~= 0 then
    vim.notify('git blame failed', vim.log.levels.WARN)
    return
  end
  vim.notify(vim.trim(res.stdout or ''), vim.log.levels.INFO, { title = 'git blame' })
end

local function show_blame_virt(bufnr)
  pcall(vim.api.nvim_buf_clear_namespace, bufnr, blame_ns, 0, -1)
  if not blame_enabled[bufnr] then return end
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then return end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  vim.system({ 'git', 'blame', '-L', lnum .. ',' .. lnum, '--porcelain', '--', name }, {
    cwd = vim.fn.fnamemodify(name, ':h'),
    text = true,
  }, function(res)
    if res.code ~= 0 then return end
    local author = res.stdout:match 'author (.-)\n'
    local summary = res.stdout:match 'summary (.-)\n'
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) or not blame_enabled[bufnr] then return end
      pcall(vim.api.nvim_buf_set_extmark, bufnr, blame_ns, lnum - 1, 0, {
        virt_text = { { ('  %s, %s'):format(author or '?', summary or ''), 'Comment' } },
        virt_text_pos = 'eol',
      })
    end)
  end)
end

function M.toggle_current_line_blame()
  local bufnr = vim.api.nvim_get_current_buf()
  blame_enabled[bufnr] = not blame_enabled[bufnr]
  show_blame_virt(bufnr)
end

function M.diffthis(rev)
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  local dir = vim.fn.fnamemodify(name, ':h')
  local ref = (rev == nil or rev == '') and ':0' or rev
  local res = vim.system({ 'git', 'show', ref .. ':./' .. vim.fn.fnamemodify(name, ':t') }, { cwd = dir, text = true }):wait()
  if res.code ~= 0 then
    vim.notify('git show failed: ' .. (res.stderr or ''), vim.log.levels.ERROR)
    return
  end
  vim.cmd 'vsplit'
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(res.stdout or '', '\n'))
  vim.bo[buf].filetype = vim.bo[bufnr].filetype
  vim.cmd 'diffthis'
  vim.cmd 'wincmd p'
  vim.cmd 'diffthis'
end

function M.select_hunk()
  local bufnr = vim.api.nvim_get_current_buf()
  local h = hunk_under_cursor(bufnr)
  if not h then return end
  local s, e = hunk_range(h)
  vim.cmd(('normal! %dGV%dG'):format(s, e))
end

function M.setup()
  vim.api.nvim_set_hl(0, 'GitSignsAdd', { fg = '#a6e3a1', default = true })
  vim.api.nvim_set_hl(0, 'GitSignsChange', { fg = '#f9e2af', default = true })
  vim.api.nvim_set_hl(0, 'GitSignsDelete', { fg = '#f38ba8', default = true })

  local group = vim.api.nvim_create_augroup('custom-gitsigns', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'FocusGained' }, {
    group = group,
    callback = function(a) M.refresh(a.buf) end,
  })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    callback = function(a) schedule_refresh(a.buf) end,
  })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorHold' }, {
    group = group,
    callback = function(a)
      if blame_enabled[a.buf] then show_blame_virt(a.buf) end
    end,
  })
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function(a)
      state[a.buf] = nil
      blame_enabled[a.buf] = nil
    end,
  })

  vim.keymap.set('n', ']c', function() M.nav_hunk 'next' end, { desc = 'Jump to next git [c]hange' })
  vim.keymap.set('n', '[c', function() M.nav_hunk 'prev' end, { desc = 'Jump to previous git [c]hange' })
  vim.keymap.set('n', '<leader>hs', M.stage_hunk, { desc = 'git [s]tage hunk' })
  vim.keymap.set('n', '<leader>hr', M.reset_hunk, { desc = 'git [r]eset hunk' })
  vim.keymap.set('n', '<leader>hS', M.stage_buffer, { desc = 'git [S]tage buffer' })
  vim.keymap.set('n', '<leader>hR', M.reset_buffer, { desc = 'git [R]eset buffer' })
  vim.keymap.set('n', '<leader>hp', M.preview_hunk, { desc = 'git [p]review hunk' })
  vim.keymap.set('n', '<leader>hb', M.blame_line, { desc = 'git [b]lame line' })
  vim.keymap.set('n', '<leader>hd', function() M.diffthis() end, { desc = 'git [d]iff against index' })
  vim.keymap.set('n', '<leader>hD', function() M.diffthis 'HEAD' end, { desc = 'git [D]iff against last commit' })
  vim.keymap.set('n', '<leader>tb', M.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
  vim.keymap.set({ 'o', 'x' }, 'ih', M.select_hunk, { desc = 'select git hunk' })
end

return M
