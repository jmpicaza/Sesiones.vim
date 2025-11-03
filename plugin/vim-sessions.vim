" ============================================================================
" File: vim-sessions.vim  
" Description: Professional session manager for Vim and Neovim
" Author: jmpicaza
" Version: 2.0
" Last Modified: 2025-11-03
" License: MIT
" Repository: https://github.com/jmpicaza/vim-sessions.vim
" ============================================================================

" Prevent double loading
if exists('g:loaded_vim-sessions') || &compatible
  finish
endif
let g:loaded_vim-sessions = 1

" Save cpoptions and set to vim defaults
let s:save_cpo = &cpoptions
set cpoptions&vim

" ============================================================================
" Configuration and Setup
" ============================================================================

" Session directory - XDG compliant with legacy support
if exists('g:vim-sessions_path')
  let g:vim-sessions_dir = expand(g:vim-sessions_path)
elseif !exists('g:vim-sessions_dir')
  let g:vim-sessions_dir = has('nvim') ? stdpath('data') . '/sessions' : expand('~/.vim/sessions')
endif

" Configuration defaults
let g:vim-sessions_autosave = get(g:, 'vim-sessions_autosave', 0)
let g:vim-sessions_include_tabpages = get(g:, 'vim-sessions_include_tabpages', 1)  
let g:vim-sessions_include_buffers = get(g:, 'vim-sessions_include_buffers', 0)

" Auto-save on exit if enabled
if g:vim-sessions_autosave
  augroup vim-sessions_autosave
    autocmd!
    autocmd VimLeavePre * if !empty(expand('%')) | SessionSave | endif
  augroup END
endif

" ============================================================================
" User Commands
" ============================================================================

command! -nargs=? -bang -complete=customlist,vim-sessions#complete SessionSave   call vim-sessions#save(<q-args>, <bang>0)
command! -nargs=? -complete=customlist,vim-sessions#complete SessionLoad         call vim-sessions#load(<q-args>)
command! -nargs=? -complete=customlist,vim-sessions#complete SessionDelete       call vim-sessions#delete(<q-args>)
command! -nargs=0 SessionList                                                call vim-sessions#list()
command! -nargs=0 SessionsEdit                                               call vim-sessions#edit()

" ============================================================================
" Auto-save functionality
" ============================================================================
if g:vim-sessions_autosave
  augroup vim-sessions_autosave
    autocmd!
    autocmd VimLeave * call vim-sessions#save('', 1)
  augroup END
endif

" ============================================================================
" Legacy key mappings (optional - users can disable in their vimrc)
" ============================================================================
if !exists('g:vim-sessions_no_mappings') || !g:vim-sessions_no_mappings
  nnoremap <F3> :SessionSave<CR>
  nnoremap <S-F3> :SessionLoad<CR>
  nnoremap <C-S-F3> :SessionSave!<CR>
  nnoremap d<F3> :SessionDelete<CR>
endif

" Restore cpoptions
let &cpoptions = s:save_cpo
unlet s:save_cpo

" EOF
