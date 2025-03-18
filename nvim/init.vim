set expandtab
set shiftwidth=4
set tabstop=4
set hidden
set signcolumn=yes:2
" set relativenumber
" set number
set nu rnu
set termguicolors
set undofile
" set spell
set title
set ignorecase
set smartcase
set wildmode=longest:full,full
set nowrap
set nolist
set mouse=a
set scrolloff=8
set sidescrolloff=8
set nojoinspaces
set splitright
set clipboard=unnamedplus
set confirm
set exrc
set cursorline

call plug#begin('~/.vim/plugged')
	Plug 'neoclide/coc.nvim', {'branch':'release'}
	Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
	Plug 'junegunn/fzf.vim'
	Plug 'stsewd/fzf-checkout.vim'
	Plug 'preservim/nerdtree'
	Plug 'jiangmiao/auto-pairs'
	Plug 'nvim-lua/plenary.nvim'
	Plug 'sindrets/diffview.nvim'
	Plug 'ibhagwan/fzf-lua'
	Plug 'NeogitOrg/neogit'
	Plug 'voldikss/vim-floaterm'
	Plug 'charlespascoe/vim-go-syntax'
	Plug 'diegoulloao/neofusion.nvim'
	Plug 'arzg/vim-colors-xcode'
	Plug 'dense-analysis/ale'
	Plug 'vim-airline/vim-airline'
    Plug 'rebelot/kanagawa.nvim'
call plug#end()


" ****************************** COC CONFIG ******************************
"
set hidden
set cmdheight=2
set updatetime=300
set shortmess+=c
set signcolumn=yes


nmap gd :call CocAction('jumpDefinition')<CR>
nmap gr :call CocAction('jumpReferences')<CR>
nmap gi :call CocAction('jumpImplementation')<CR>
nmap gI :call CocAction('implementations')<CR>
nmap gu :call CocAction('jumpUsed')<CR>
nmap gy :call CocAction('jumpTypeDefinition')<CR>

nnoremap <leader>a <Plug>(coc-codeaction-cursor)
nnoremap <leader>A <Plug>(coc-codeaction-selected)

" Show hover when provider exists, fallback to vim's builtin behavior.
function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('definitionHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

nnoremap <silent> K :call ShowDocumentation()<CR>

nnoremap <space>d :CocDiagnostics<CR>
nnoremap <space>f :call CocActionAsync('format')<CR>

"
" *******************************************************************





" *************************** FZF CONFIG ****************************
"
let g:fzf_layout = { 'up': '~90%', 'window': { 'width': 0.8, 'height': 0.8, 'yoffset':0.5, 'xoffset': 0.5 } }
let $FZF_DEFAULT_OPTS = '--layout=reverse --info=inline'

" Customise the Files command to use rg which respects •gitignore files
command! -bang -nargs=? -complete=dir Files
            \ call fzf#run(fzf#wrap('files', fzf#vim#with_preview({ 'dir': <q-args>, 'sink': 'e', 'source': 'rg --files --hidden' }), <bang>0))

" Add an AllFiles variation that ignores •gitignore files 
command! -bang -nargs=? -complete=dir AllFiles
	        \call fzf#run(fzf#wrap('allfiles', fzf#vim#with_preview({ 'dir': <q-args>, 'sink': 'e', 'source': 'rg --files --hidden -—no-ignore' }), <bang>0))


nmap <leader>f :Files<cr>
nmap <leader>b :Buffers<cr>
nmap <leader>h :History<cr>
nmap <leader>r :Rg<cr>
nmap <leader>R :Rg<space>
nmap <leader>gb :GBranches<cr>
"
" *******************************************************************


" ************************ NERDTREE CONFIG **************************
"
nnoremap <leader>n :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
nnoremap <C-f> :NEDTreeFind<CR>
"
" *******************************************************************



" ************************ FLOATERM CONFIG **************************
"
nnoremap <silent> <F7>		:FloatermNew<CR>
tnoremap <silent> <F7>		<C-\><C-n>:FloatermNew<CR>
nnoremap <silent> <F8>		:FloatermPrev<CR>
tnoremap <silent> <F8>		<C-\><C-n>:FloatermPrev<CR>
nnoremap <silent> <F9>		:FloatermNext<CR>
tnoremap <silent> <F9>		<C-\><C-n>:FloatermNext<CR>
nnoremap <silent> <F12>		:FloatermToggle<CR>
tnoremap <silent> <F12>		<C-\><C-n>:FloatermToggle<CR>
"
" *******************************************************************



" ************************ NEOGIT CONFIG ****************************
"
lua require("neogit").setup{}
"
" *******************************************************************



" ************************* KEY REMAPS ******************************
"
nnoremap <C-h> :noh<CR>
inoremap jk <Esc>
inoremap kj <Esc>
"
" *******************************************************************




" ********************** LOOKUP-LIST CONFIG *************************
"
nmap :ln<CR> :lnext<CR>
nmap :lp<CR> :lprevious<CR>
nmap :lf<CR> :lfirst<CR>
nmap :ll<CR> :lclose<CR>
"
" *******************************************************************



" ********************** ALE CONFIG *************************
"
let g:go_highlight_diagnostic_errors = 1
let g:go_highlight_diagnostic_warnings = 1

let g:ale_linters = {
			\ 'go': ['gopls'],
			\ }
"
" *******************************************************************




" ********************** KANAGAWA CONFIG *************************
"
lua <<EOF
require('kanagawa').setup({
    compile = false,             -- enable compiling the colorscheme
    undercurl = true,            -- enable undercurls
    commentStyle = { italic = true },
    functionStyle = {},
    keywordStyle = { italic = true},
    statementStyle = { bold = true },
    typeStyle = {},
    transparent = false,         -- do not set background color
    dimInactive = false,         -- dim inactive window `:h hl-NormalNC`
    terminalColors = true,       -- define vim.g.terminal_color_{0,17}
    colors = {                   -- add/modify theme and palette colors
        palette = {},
        theme = { wave = {}, lotus = {}, dragon = {}, all = {} },
    },
    overrides = function(colors) -- add/modify highlights
        return {}
    end,
    theme = "wave",              -- Load "wave" theme
    background = {               -- map the value of 'background' option to a theme
        dark = "wave",           -- try "dragon" !
        light = "lotus"
    },
})

-- setup must be called before loading
vim.cmd("colorscheme kanagawa-dragon")
EOF
"
" *******************************************************************





