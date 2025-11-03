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
if exists('g:loaded_vim_sessions') || &compatible
  finish
endif
let g:loaded_vim_sessions = 1

" Save cpoptions and set to vim defaults
let s:save_cpo = &cpoptions
set cpoptions&vim

" ============================================================================
" Configuration and Setup
" ============================================================================

" Session directory - XDG compliant with legacy support
if exists('g:vim_sessions_path')
  let g:vim_sessions_dir = expand(g:vim_sessions_path)
elseif !exists('g:vim_sessions_dir')
  let g:vim_sessions_dir = has('nvim') ? stdpath('data') . '/sessions' : expand('~/.vim/sessions')
endif

" Configuration defaults
let g:vim_sessions_autosave = get(g:, 'vim_sessions_autosave', 0)
let g:vim_sessions_include_tabpages = get(g:, 'vim_sessions_include_tabpages', 1)  
let g:vim_sessions_include_buffers = get(g:, 'vim_sessions_include_buffers', 0)

" Auto-save on exit if enabled
if g:vim_sessions_autosave
  augroup vim_sessions_autosave
    autocmd!
    autocmd VimLeavePre * if !empty(expand('%')) | SessionSave | endif
  augroup END
endif

" ============================================================================
" User Commands
" ============================================================================

command! -nargs=? -bang -complete=customlist,vimsessions#complete SessionSave   call vimsessions#save(<q-args>, <bang>0)
command! -nargs=? -complete=customlist,vimsessions#complete SessionLoad         call vimsessions#load(<q-args>)
command! -nargs=? -complete=customlist,vimsessions#complete SessionDelete       call vimsessions#delete(<q-args>)
command! -nargs=0 SessionList                                                call vimsessions#list()
command! -nargs=0 SessionsEdit                                               call vimsessions#edit()

" ============================================================================
" Auto-save functionality
" ============================================================================
if g:vim_sessions_autosave
  augroup vim_sessions_autosave
    autocmd!
    autocmd VimLeave * call vimsessions#save('', 1)
  augroup END
endif

" ============================================================================
" Legacy key mappings (optional - users can disable in their vimrc)
" ============================================================================
if !exists('g:vim_sessions_no_mappings') || !g:vim_sessions_no_mappings
  nnoremap <F3> :SessionSave<CR>
  nnoremap <S-F3> :SessionLoad<CR>
  nnoremap <C-S-F3> :SessionSave!<CR>
  nnoremap d<F3> :SessionDelete<CR>
endif

" Restore cpoptions
let &cpoptions = s:save_cpo
unlet s:save_cpo

" EOF
