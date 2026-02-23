local map = vim.keymap.set

local function nmap(lhs, rhs, desc)
  map('n', lhs, rhs, { silent = true, desc = desc })
end

nmap('<leader>ww', vim.cmd.write, 'Write')
nmap('<leader>wq', vim.cmd.quit, 'Quit')
nmap('<leader>wx', vim.cmd.xit, 'Save & Quit')

nmap('<leader>bn', vim.cmd.bnext, 'Next Buffer')
nmap('<leader>bp', vim.cmd.bprevious, 'Previous Buffer')
nmap('<leader>bd', vim.cmd.bdelete, 'Delete Buffer')
nmap('<leader>ba', function()
  vim.cmd('%bdelete | e# | bd#')
end, 'Delete Other Buffers')
nmap('<leader>bf', vim.cmd.bfirst, 'First Buffer')
nmap('<leader>bl', vim.cmd.blast, 'Last Buffer')

nmap('<leader>s-', vim.cmd.split, 'Horizontal Split')
nmap('<leader>s|', vim.cmd.vsplit, 'Vertical Split')
nmap('<leader>sc', vim.cmd.close, 'Close Split')
nmap('<leader>so', vim.cmd.only, 'Close Other Splits')
