-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Set <space> as the leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Nerd Font installed
vim.g.have_nerd_font = true

-- Line numbers default
vim.opt.number = true

vim.opt.relativenumber = false

-- Enable mouse mode
vim.opt.mouse = "a"

-- Don't show, since it's already in the status line
vim.opt.showmode = false

-- Sync clipboard between OS and Neovim
vim.opt.clipboard = "unnamedplus"

-- Enable break indent
vim.opt.breakindent = true

-- Save undo history
vim.opt.undofile = true

-- Case-insensitive while searching
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on by default
vim.opt.signcolumn = "yes"

-- Decrease update time for faster response
vim.opt.updatetime = 200

-- Decrease mapped sequence wait time
-- Display which-key popup sooner
vim.opt.timeoutlen = 300

-- How splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Helps display certain whitespace characters in the editor
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions live, as you type!
vim.opt.inccommand = "split"

vim.opt.cursorline = true
-- Show which line your cursor is on

-- Minimal number of screen lines to keep above and below the cursor
vim.opt.scrolloff = 8

-- Enable true color support
vim.opt.termguicolors = true

-- views can only be fully collapsed with the global statusline
-- used for avante.nvim plugin
vim.opt.laststatus = 3

-- Enable spell checking
vim.opt.spell = true

-- Set spell checking language to English
vim.opt.spelllang = "en"

-- Better completion experience
vim.opt.completeopt = { "menuone", "noselect" }

vim.g.lazyvim_picker = "fzf"
