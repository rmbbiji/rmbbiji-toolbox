" Lightweight Vim config for terminal editing.
" Works with Vim 9.1 huge builds and does not require external plugins.

scriptencoding utf-8
set encoding=utf-8

" Load filetype detection, plugins, indentation, and syntax highlighting.
filetype plugin indent on
syntax enable

" Interface
set number
set ruler
set showcmd
set showmode
set laststatus=2
set cmdheight=1
set signcolumn=yes
set mouse=a
set title
set visualbell
set noerrorbells
set updatetime=300
set timeoutlen=500
set ttimeoutlen=20

if has('termguicolors')
  set termguicolors
endif

if exists('+cursorline')
  set cursorline
endif

" Editing
set hidden
set backspace=indent,eol,start
set virtualedit=block
set formatoptions-=o
set formatoptions-=r
set completeopt=menuone,noinsert,noselect
set wildmenu
set wildmode=longest:full,full
set wildignorecase
set shortmess+=c

" Indentation defaults. Filetype rules below override where useful.
set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4
set shiftround
set autoindent
set smartindent

" Search
set ignorecase
set smartcase
set incsearch
set hlsearch

" Splits and scrolling
set splitbelow
set splitright
set scrolloff=5
set sidescrolloff=8

" Files, backups, and undo history
set nobackup
set nowritebackup
set noswapfile
set undofile
set undodir^=~/.vim/undo//
set directory^=~/.vim/swap//
set backupdir^=~/.vim/backup//

" Make whitespace visible without being noisy.
set list
set listchars=tab:>-,trail:·,extends:>,precedes:<,nbsp:+

" Color scheme: use Vim's built-in default when available.
if exists('g:colors_name') == 0
  silent! colorscheme default
endif

" Leader key and practical mappings.
let mapleader = ' '
nnoremap <silent> <leader>w :write<CR>
nnoremap <silent> <leader>q :quit<CR>
nnoremap <silent> <leader>Q :quit!<CR>
nnoremap <silent> <leader>h :nohlsearch<CR>
nnoremap <silent> <leader>n :set invnumber invrelativenumber<CR>
nnoremap <silent> <leader>l :set invlist<CR>

" Easier split navigation.
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Keep selection while indenting visual blocks.
vnoremap < <gv
vnoremap > >gv

" Move selected lines up/down.
xnoremap J :move '>+1<CR>gv=gv
xnoremap K :move '<-2<CR>gv=gv

" Quickfix and location list navigation.
nnoremap <silent> ]q :cnext<CR>
nnoremap <silent> [q :cprevious<CR>
nnoremap <silent> ]l :lnext<CR>
nnoremap <silent> [l :lprevious<CR>

" A compact status line with file, modified flag, filetype, encoding, and cursor.
set statusline=%f
set statusline+=%m%r%h%w
set statusline+=%=
set statusline+=[%{&filetype==#''?'noft':&filetype}]
set statusline+=\ %{&fileencoding==#''?&encoding:&fileencoding}
set statusline+=\ %l:%c
set statusline+=\ %p%%

" Filetype-specific preferences.
augroup codex_vimrc
  autocmd!
  autocmd BufWritePre * %s/\s\+$//e

  autocmd FileType python setlocal expandtab tabstop=4 softtabstop=4 shiftwidth=4 textwidth=88 colorcolumn=89
  autocmd FileType sh,zsh,bash setlocal expandtab tabstop=2 softtabstop=2 shiftwidth=2
  autocmd FileType json,yaml,toml,html,css,javascript,typescript setlocal expandtab tabstop=2 softtabstop=2 shiftwidth=2
  autocmd FileType markdown,text setlocal wrap linebreak nolist spell
  autocmd FileType gitcommit setlocal spell textwidth=72 colorcolumn=73
augroup END

" Python helpers.
let g:python_recommended_style = 0
let g:netrw_banner = 0
let g:netrw_liststyle = 3

" Create Vim state directories if they do not exist.
if exists('*mkdir')
  silent! call mkdir(expand('~/.vim/undo'), 'p')
  silent! call mkdir(expand('~/.vim/swap'), 'p')
  silent! call mkdir(expand('~/.vim/backup'), 'p')
endif
