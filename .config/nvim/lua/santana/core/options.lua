local opt = vim.opt
vim.g.mapleader = ' '

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.termguicolors = true
opt.scrolloff = 8
opt.signcolumn = 'yes'
opt.splitright = true
opt.splitbelow = true
opt.wrap = false
opt.showmode = false
opt.mouse = 'a'
opt.splitkeep = 'screen'

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.undodir = vim.fn.stdpath('data') .. '/undo'

opt.updatetime = 200
opt.timeoutlen = 300
opt.lazyredraw = true

opt.completeopt = { 'menuone', 'noselect' }

opt.clipboard = 'unnamedplus'
opt.fileencoding = 'utf-8'

opt.colorcolumn = '100'
opt.confirm = true

opt.conceallevel = 2

opt.sessionoptions = {
  'buffers',
  'curdir',
  'folds',
  'help',
  'tabpages',
  'winsize',
  'localoptions',
}
