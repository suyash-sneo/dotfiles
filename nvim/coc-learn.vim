call plug#begin('~/.vim/plugged')
    Plug 'neoclide/coc.nvim', {'branch':'release'}
call plug#end()

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

" ************************* KEY REMAPS ******************************
"
inoremap jk <Esc>
inoremap kj <Esc>
nnoremap <C-h> :noh<CR>
"
" *******************************************************************

