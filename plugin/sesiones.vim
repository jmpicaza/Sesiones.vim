" ============================================================================
" File: sesiones.vim  
" Description: Professional session manager for Vim and Neovim
" Author: jmpicaza
" Version: 2.0
" Last Modified: 2025-11-03
" License: MIT
" Repository: https://github.com/jmpicaza/Sesiones.vim
" ============================================================================

" Prevent double loading
if exists('g:loaded_sesiones') || &compatible
  finish
endif
let g:loaded_sesiones = 1

" Save cpoptions and set to vim defaults
let s:save_cpo = &cpoptions
set cpoptions&vim

" ============================================================================
" Configuration and Setup
" ============================================================================

" Session directory - XDG compliant with legacy support
if exists('g:sesiones_path')
  let g:sesiones_dir = expand(g:sesiones_path)
elseif !exists('g:sesiones_dir')
  let g:sesiones_dir = has('nvim') ? stdpath('data') . '/sessions' : expand('~/.vim/sessions')
endif

" Configuration defaults
let g:sesiones_autosave = get(g:, 'sesiones_autosave', 0)
let g:sesiones_include_tabpages = get(g:, 'sesiones_include_tabpages', 1)  
let g:sesiones_include_buffers = get(g:, 'sesiones_include_buffers', 0)

" Auto-save on exit if enabled
if g:sesiones_autosave
  augroup sesiones_autosave
    autocmd!
    autocmd VimLeavePre * if !empty(expand('%')) | SessionSave | endif
  augroup END
endif

" ============================================================================
" User Commands
" ============================================================================

command! -nargs=? -bang -complete=customlist,sesiones#complete SessionSave   call sesiones#save(<q-args>, <bang>0)
command! -nargs=? -complete=customlist,sesiones#complete SessionLoad         call sesiones#load(<q-args>)
command! -nargs=? -complete=customlist,sesiones#complete SessionDelete       call sesiones#delete(<q-args>)
command! -nargs=0 SessionList                                                call sesiones#list()
command! -nargs=0 SessionsEdit                                               call sesiones#edit()

" ============================================================================
" Auto-save functionality
" ============================================================================
if g:sesiones_autosave
  augroup sesiones_autosave
    autocmd!
    autocmd VimLeave * call sesiones#save('', 1)
  augroup END
endif

" ============================================================================
" Legacy key mappings (optional - users can disable in their vimrc)
" ============================================================================
if !exists('g:sesiones_no_mappings') || !g:sesiones_no_mappings
  nnoremap <F3> :SessionSave<CR>
  nnoremap <S-F3> :SessionLoad<CR>
  nnoremap <C-S-F3> :SessionSave!<CR>
  nnoremap d<F3> :SessionDelete<CR>
endif

" Restore cpoptions
let &cpoptions = s:save_cpo
unlet s:save_cpo

" EOF
