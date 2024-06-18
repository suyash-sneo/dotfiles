set expandtab
set shiftwidth=4 
set tabstop=4
set hidden
set signcolumn=yes:2
" set relativenumber
set number
set termguicolors
set undofile
" set spell
set title
set ignorecase
set smartcase
set wildmode=longest:full,full
set nowrap
set list
set mouse=a
set scrolloff=8
set sidescrolloff=8
set nojoinspaces
set splitright
set clipboard=unnamedplus
set confirm
set exrc
" set showtabline=2

call plug#begin('~/.vim/plugged')
    Plug 'fatih/vim-go'
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
    Plug 'doums/darcula'
    Plug 'diegoulloao/neofusion.nvim'
    Plug 'arzg/vim-colors-xcode'
    " Plug 'Shougo/deoplete.nvim'
    Plug 'mfussenegger/nvim-dap'
    Plug 'leoluz/nvim-dap-go'
    Plug 'nvim-neotest/nvim-nio'
    Plug 'rcarriga/nvim-dap-ui'
call plug#end()




" *********************************** COC CONFIG ********************
"
set hidden
set cmdheight=2
set updatetime=300
set shortmess+=c
set signcolumn=yes

" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()

" Use `[c` and `]c` to navigate diagnostics
nmap <silent> [c <Plug>(coc-diagnostic-prev)
nmap <silent> ]c <Plug>(coc-diagnostic-next)

" Remap keys for gotos
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use U to show documentation in preview window
nnoremap <silent> U :call <SID>show_documentation()<CR>

" Remap for rename current word
nmap <leader>rn <Plug>(coc-rename)

" Remap for format selected region
vmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)
" Show all diagnostics
nnoremap <silent> <space>a  :<C-u>CocList diagnostics<cr>
" Manage extensions
nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
" Show commands
nnoremap <silent> <space>c  :<C-u>CocList commands<cr>
" Find symbol of current document
nnoremap <silent> <space>o  :<C-u>CocList outline<cr>
" Search workspace symbols
nnoremap <silent> <space>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent> <space>p  :<C-u>CocListResume<CR>
" 
" **********************************************************************




" *********************** FZF CONFIG ***********************************
"
let g:fzf_layout = { 'up': '~90%', 'window': { 'width': 0.8, 'height': 0.8, 'yoffset':0.5, 'xoffset': 0.5 } }
let $FZF_DEFAULT_OPTS = '--layout=reverse --info=inline'

" Customise the Files command to use rg which respects .gitignore files
command! -bang -nargs=? -complete=dir Files
    \ call fzf#run(fzf#wrap('files', fzf#vim#with_preview({ 'dir': <q-args>, 'sink': 'e', 'source': 'rg --files --hidden' }), <bang>0))

" Add an AllFiles variation that ignores .gitignore files
command! -bang -nargs=? -complete=dir AllFiles
    \ call fzf#run(fzf#wrap('allfiles', fzf#vim#with_preview({ 'dir': <q-args>, 'sink': 'e', 'source': 'rg --files --hidden --no-ignore' }), <bang>0))

nmap <leader>f :Files<cr>
nmap <leader>F :AllFiles<cr>
nmap <leader>b :Buffers<cr>
nmap <leader>h :History<cr>
nmap <leader>r :Rg<cr>
nmap <leader>R :Rg<space>
nmap <leader>gb :GBranches<cr>
" 
" *********************************************************************




" ************************* NERDTREE CONFIG ***************************
"
nnoremap <leader>n :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
nnoremap <C-f> :NERDTreeFind<CR>
" 
" *********************************************************************






" ************************* FLOATERM CONFIG ***************************
"
nnoremap   <silent>   <F7>    :FloatermNew<CR>
tnoremap   <silent>   <F7>    <C-\><C-n>:FloatermNew<CR>
nnoremap   <silent>   <F8>    :FloatermPrev<CR>
tnoremap   <silent>   <F8>    <C-\><C-n>:FloatermPrev<CR>
nnoremap   <silent>   <F9>    :FloatermNext<CR>
tnoremap   <silent>   <F9>    <C-\><C-n>:FloatermNext<CR>
nnoremap   <silent>   <F12>   :FloatermToggle<CR>
tnoremap   <silent>   <F12>   <C-\><C-n>:FloatermToggle<CR>
" 
" *********************************************************************


" ************************* THEME CONFIG ***************************
"
" colorscheme darcula
" set background=dark
" colorscheme neofusion
colorscheme xcodedarkhc
" 
" *********************************************************************



" ************************* NEOGIT CONFIG ***************************
"
lua require("neogit").setup{}
" 
" *********************************************************************




" ************************* INIT LUA CONFIG ***************************
"
" lua require('myconfig')
" lua require('dap-repl-conf')
"
" *********************************************************************





" *************************** KEY REMAPS *****************************
" 
nnoremap <C-h> :noh<CR>
inoremap jk <Esc>
inoremap kj <Esc>
" 
" *********************************************************************


" *************************** VIM-GO CONFIG *****************************
"
au filetype go inoremap <buffer> . .<C-x><C-o>
let g:go_fmt_autosave = 0
set completeopt=menu,menuone,noselect
"
" *********************************************************************





" ************************* LOOKUP-LIST CONFIG ***************************
"
nmap :ln<CR> :lnext<CR>
nmap :lp<CR> :lprevious<CR>
nmap :lf<CR> :lfirst<CR>
nmap :ll<CR> :lclose<CR>
" 
" *********************************************************************







