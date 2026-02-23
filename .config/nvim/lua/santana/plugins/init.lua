-- lazy.nvim bootstrap + setup (clean, safe, fast)
local uv = vim.uv or vim.loop
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'

if not uv.fs_stat(lazypath) then
  local repo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable',
    repo,
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_err_writeln('Failed to clone lazy.nvim:\n' .. out)
    return
  end
end

vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  spec = {},

  defaults = { lazy = false, version = nil },
  install = { colorscheme = { 'habamax' } },
  checker = { enabled = true, notify = false },
  change_detection = { enabled = true, notify = false },

  ui = { border = 'rounded' },

  performance = {
    cache = { enabled = true },
    rtp = {
      disabled_plugins = {
        'gzip',
        'matchit',
        'matchparen',
        'netrwPlugin',
        'tarPlugin',
        'tohtml',
        'tutor',
        'zipPlugin',
      },
    },
  },
})
