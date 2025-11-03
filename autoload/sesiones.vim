" ============================================================================
" File: autoload/sesiones.vim
" Description: Session management for Vim and Neovim - Core Functions
" Author: jmpicaza
" Version: 2.0
" Last Modified: 2025-11-03
" License: MIT
" ============================================================================

" Session filename generation {{{1
function! sesiones#get_session_name() abort
  let l:current_file = expand('%:p')
  return empty(l:current_file) ? getcwd() : l:current_file
endfunction

function! sesiones#encode_path(path) abort
  let l:safe = substitute(resolve(expand(a:path)), '^[/\\]*', '', '')
  let l:safe = substitute(l:safe, '[/\\:< >"|*?]', '_', 'g')
  
  " Handle very long paths with hash
  if len(l:safe) > 200
    let l:hash = abs(s:hash_djb2(a:path)) % 1000000
    let l:safe = l:safe[:80] . '_H' . l:hash
  endif
  
  return empty(l:safe) ? 'session_default' : l:safe
endfunction

function! s:hash_djb2(str) abort
  let l:hash = 5381
  for l:i in range(len(a:str))
    let l:hash = (l:hash * 33 + char2nr(a:str[l:i])) % 2147483647
  endfor
  return l:hash
endfunction

" Session file operations {{{1
function! sesiones#session_file(name) abort
  let l:name = empty(a:name) ? sesiones#encode_path(sesiones#get_session_name()) : a:name
  
  " Sanitize user-provided names
  if !sesiones#is_encoded_name(l:name)
    let l:name = substitute(l:name, '[^A-Za-z0-9._-]', '_', 'g')
  endif
  
  call mkdir(g:sesiones_dir, 'p')
  return g:sesiones_dir . '/' . l:name . '.vim'
endfunction

function! sesiones#is_encoded_name(name) abort
  return a:name =~# '\([=][+-]\|_H[0-9]\+\|^session_\)'
endfunction

" Nickname management {{{1
function! sesiones#nicknames_file() abort
  return g:sesiones_dir . '/.sessions_nicknames'
endfunction

function! sesiones#load_nicknames() abort
  let l:file = sesiones#nicknames_file()
  let l:nicknames = {}
  
  if filereadable(l:file)
    for l:line in readfile(l:file)
      let l:parts = split(l:line, ':')
      if len(l:parts) >= 2
        let l:nicknames[l:parts[1]] = l:parts[0]
      endif
    endfor
  endif
  
  return l:nicknames
endfunction

function! sesiones#save_nicknames(nicknames) abort
  let l:lines = []
  for [l:filename, l:nickname] in items(a:nicknames)
    call add(l:lines, l:nickname . ':' . l:filename)
  endfor
  call writefile(l:lines, sesiones#nicknames_file())
endfunction

function! sesiones#set_nickname(session_file, nickname) abort
  let l:filename = fnamemodify(a:session_file, ':t:r')
  let l:nicknames = sesiones#load_nicknames()
  let l:nicknames[l:filename] = a:nickname
  call sesiones#save_nicknames(l:nicknames)
endfunction

function! sesiones#find_by_nickname(name) abort
  " Try exact filename first
  let l:path = sesiones#session_file(a:name)
  if filereadable(l:path)
    return fnamemodify(l:path, ':t:r')
  endif
  
  " Try nickname lookup
  let l:nicknames = sesiones#load_nicknames()
  for [l:filename, l:nickname] in items(l:nicknames)
    if l:nickname ==# a:name
      return l:filename
    endif
  endfor
  
  return ''
endfunction

" Session operations {{{1
function! sesiones#save(name, bang) abort
  " Configure session options
  let l:original = &sessionoptions
  set sessionoptions=buffers,curdir,folds,help,tabpages,winsize,winpos
  if g:sesiones_include_tabpages | set sessionoptions+=tabpages | endif
  if g:sesiones_include_buffers | set sessionoptions+=buffers | endif
  
  try
    let l:filename = sesiones#encode_path(sesiones#get_session_name())
    let l:session_file = sesiones#session_file(l:filename)
    let l:nickname = empty(a:name) ? expand('%:t') : a:name
    if empty(l:nickname) | let l:nickname = 'session' | endif
    
    execute 'mksession! ' . fnameescape(l:session_file)
    call sesiones#set_nickname(l:session_file, l:nickname)
    
    echohl MoreMsg
    echo 'Saved session: ' . l:nickname . ' (' . fnamemodify(l:session_file, ':t') . ')'
    echohl None
  catch
    echohl ErrorMsg
    echo 'Failed to save session: ' . v:exception
    echohl None
  finally
    let &sessionoptions = l:original
  endtry
endfunction

function! sesiones#load(name) abort
  if empty(a:name)
    let l:filename = sesiones#encode_path(sesiones#get_session_name())
    let l:path = sesiones#session_file(l:filename)
    
    if !filereadable(l:path)
      echohl WarningMsg
      echo 'There is no session associated with this directory: ' . getcwd()
      echohl None
      return
    endif
  else
    let l:filename = sesiones#find_by_nickname(a:name)
    if empty(l:filename)
      echohl WarningMsg
      echo 'Session not found: ' . a:name
      echohl None
      return
    endif
    let l:path = sesiones#session_file(l:filename)
  endif
  
  try
    execute 'source ' . fnameescape(l:path)
    echohl MoreMsg
    echo 'Loaded session: ' . (empty(a:name) ? fnamemodify(l:path, ':t:r') : a:name)
    echohl None
  catch
    echohl ErrorMsg
    echo 'Failed to load session: ' . v:exception
    echohl None
  endtry
endfunction

function! sesiones#delete(name) abort
  let l:filename = empty(a:name) ? sesiones#encode_path(sesiones#get_session_name()) : sesiones#find_by_nickname(a:name)
  if empty(l:filename)
    echohl WarningMsg
    echo 'Session not found: ' . (empty(a:name) ? 'current directory' : a:name)
    echohl None
    return
  endif
  
  let l:path = sesiones#session_file(l:filename)
  if !filereadable(l:path)
    echohl WarningMsg
    echo 'Session file not found: ' . fnamemodify(l:path, ':t')
    echohl None
    return
  endif
  
  if delete(l:path) == 0
    " Remove nickname if exists
    let l:nicknames = sesiones#load_nicknames()
    if has_key(l:nicknames, l:filename)
      unlet l:nicknames[l:filename]
      call sesiones#save_nicknames(l:nicknames)
    endif
    
    echohl MoreMsg
    echo 'Deleted session: ' . (empty(a:name) ? fnamemodify(l:path, ':t:r') : a:name)
    echohl None
  else
    echohl ErrorMsg
    echo 'Failed to delete session: ' . fnamemodify(l:path, ':t')
    echohl None
  endif
endfunction

function! sesiones#list() abort
  let l:files = sort(glob(g:sesiones_dir . '/*.vim', 0, 1))
  if empty(l:files)
    echohl WarningMsg
    echo 'No sessions found in ' . g:sesiones_dir
    echohl None
    return
  endif
  
  echo 'Available sessions in ' . g:sesiones_dir . ':'
  echo ''
  
  let l:nicknames = sesiones#load_nicknames()
  for l:file in l:files
    let l:filename = fnamemodify(l:file, ':t:r')
    let l:nickname = get(l:nicknames, l:filename, '')
    let l:display = empty(l:nickname) ? l:filename : l:nickname . ' (' . l:filename . ')'
    let l:size = getfsize(l:file)
    let l:time = strftime('%Y-%m-%d %H:%M', getftime(l:file))
    
    echo printf('  %-40s %6s  %s', l:display, 
          \ l:size > 0 ? (l:size . 'B') : '', l:time)
  endfor
  echo ''
endfunction

" Interactive session editor {{{1
function! sesiones#edit() abort
  let l:files = sort(glob(g:sesiones_dir . '/*.vim', 0, 1))
  if empty(l:files)
    echohl WarningMsg
    echo 'No sessions found in ' . g:sesiones_dir
    echohl None
    return
  endif
  
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile filetype=sessions
  
  " Add header
  call setline(1, [
        \ '" Sesiones.vim - Interactive Session Editor',
        \ '" ',
        \ '" Instructions:',
        \ '"   <Enter>  - Load session under cursor',
        \ '"   dd       - Delete session under cursor', 
        \ '"   r        - Edit nickname for session under cursor',
        \ '"   q        - Quit without saving',
        \ '" ',
        \ '" Format: Nickname | Filename | Size | Date',
        \ '" Sessions:',
        \ '" ---------'
        \ ])
  
  " Add sessions
  let l:nicknames = sesiones#load_nicknames()
  let l:line_num = 12
  for l:file in l:files
    let l:filename = fnamemodify(l:file, ':t')
    let l:nickname = get(l:nicknames, fnamemodify(l:file, ':t:r'), fnamemodify(l:file, ':t:r'))
    let l:size = printf('%6s', getfsize(l:file) . 'B')
    let l:time = strftime('%Y-%m-%d %H:%M', getftime(l:file))
    
    call setline(l:line_num, printf('%-30s | %-30s | %s | %s', l:nickname, l:filename, l:size, l:time))
    let l:line_num += 1
  endfor
  
  " Set up mappings
  nnoremap <buffer><silent> <CR> :call <SID>load_session()<CR>
  nnoremap <buffer><silent> dd :call <SID>delete_session()<CR>
  nnoremap <buffer><silent> r :call <SID>rename_session()<CR>
  nnoremap <buffer><silent> q :close<CR>
  
  call cursor(12, 1)
endfunction

" Helper functions for session editor
function! s:get_session_info() abort
  let l:line = getline('.')
  if l:line !~# ' | '
    return ['', '']
  endif
  
  let l:parts = split(l:line, ' | ')
  if len(l:parts) < 2
    return ['', '']
  endif
  
  let l:nickname = trim(l:parts[0])
  let l:filename = trim(l:parts[1])
  if l:filename =~# '\.vim$'
    let l:filename = l:filename[:-5]  " Remove .vim extension
  endif
  
  return [l:nickname, l:filename]
endfunction

function! s:load_session() abort
  let [l:nickname, l:filename] = s:get_session_info()
  if !empty(l:filename)
    close
    call sesiones#load(l:filename)
  endif
endfunction

function! s:delete_session() abort
  let [l:nickname, l:filename] = s:get_session_info()
  if !empty(l:filename)
    if confirm('Delete session "' . l:nickname . '"?', "&Yes\n&No", 2) == 1
      call sesiones#delete(l:filename)
      delete _
      echo 'Deleted session: ' . l:nickname
    endif
  endif
endfunction

function! s:rename_session() abort
  let [l:old_nickname, l:filename] = s:get_session_info()
  if empty(l:filename)
    return
  endif
  
  let l:new_nickname = input('Edit nickname: ', l:old_nickname)
  if !empty(l:new_nickname) && l:new_nickname !=# l:old_nickname
    let l:session_file = sesiones#session_file(l:filename)
    call sesiones#set_nickname(l:session_file, l:new_nickname)
    
    " Update the line
    let l:parts = split(getline('.'), ' | ')
    let l:new_line = printf('%-30s | %s | %s | %s', l:new_nickname, l:parts[1], l:parts[2], l:parts[3])
    call setline('.', l:new_line)
    
    echo 'Renamed session to: ' . l:new_nickname
  endif
endfunction

" Command completion {{{1
function! sesiones#complete(ArgLead, CmdLine, CursorPos) abort
  let l:candidates = []
  let l:nicknames = sesiones#load_nicknames()
  
  " Add nicknames
  for l:nickname in values(l:nicknames)
    if l:nickname =~# '^' . escape(a:ArgLead, '.*^$[]')
      call add(l:candidates, l:nickname)
    endif
  endfor
  
  " Add filenames
  for l:file in glob(g:sesiones_dir . '/*.vim', 0, 1)
    let l:filename = fnamemodify(l:file, ':t:r')
    if l:filename =~# '^' . escape(a:ArgLead, '.*^$[]')
      call add(l:candidates, l:filename)
    endif
  endfor
  
  return sort(uniq(l:candidates))
endfunction

" vim:foldmethod=marker:foldlevel=0