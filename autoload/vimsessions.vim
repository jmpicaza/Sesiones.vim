" ============================================================================
" File: autoload/vimsessions.vim
" Description: Enhanced session management with special window support
" Author: jmpicaza
" Version: 2.1
" Last Modified: 2025-11-03
" License: MIT
" ============================================================================

" Session filename generation {{{1
function! vimsessions#get_session_name() abort
  let l:current_file = expand('%:p')
  return empty(l:current_file) ? getcwd() : l:current_file
endfunction

function! vimsessions#encode_path(path) abort
  let l:safe = substitute(resolve(expand(a:path)), '^[/\\]*', '', '')
  " Change replacement character from '_' to '%'
  let l:safe = substitute(l:safe, '[/\\:< >"|*?]', '%', 'g')

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
function! vimsessions#session_file(name) abort
  let l:name = empty(a:name) ? vimsessions#encode_path(vimsessions#get_session_name()) : a:name

  " Update sanitization regex to include '%' in allowed characters
  if !vimsessions#is_encoded_name(l:name)
    let l:name = substitute(l:name, '[^A-Za-z0-9._%-]', '_', 'g')
  endif

  call mkdir(g:vim_sessions_dir, 'p')
  return g:vim_sessions_dir . '/' . l:name . '.vim'
endfunction

function! vimsessions#is_encoded_name(name) abort
  return a:name =~# '\([=][+-]\|_H[0-9]\+\|^session_\)'
endfunction

" Nickname management {{{1
function! vimsessions#nicknames_file() abort
  return g:vim_sessions_dir . '/.sessions_nicknames'
endfunction

function! vimsessions#load_nicknames() abort
  let l:file = vimsessions#nicknames_file()
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

function! vimsessions#save_nicknames(nicknames) abort
  let l:lines = []
  for [l:filename, l:nickname] in items(a:nicknames)
    call add(l:lines, l:nickname . ':' . l:filename)
  endfor
  call writefile(l:lines, vimsessions#nicknames_file())
endfunction

function! vimsessions#set_nickname(session_file, nickname) abort
  let l:filename = fnamemodify(a:session_file, ':t:r')
  let l:nicknames = vimsessions#load_nicknames()
  let l:nicknames[l:filename] = a:nickname
  call vimsessions#save_nicknames(l:nicknames)
endfunction

function! vimsessions#find_by_nickname(name) abort
  " Try exact filename first
  let l:path = vimsessions#session_file(a:name)
  if filereadable(l:path)
    return fnamemodify(l:path, ':t:r')
  endif
  
  " Try nickname lookup
  let l:nicknames = vimsessions#load_nicknames()
  for [l:filename, l:nickname] in items(l:nicknames)
    if l:nickname ==# a:name
      return l:filename
    endif
  endfor
  
  return ''
endfunction

" Special window state management {{{1
function! s:save_special_windows() abort
  let l:special_windows = {}
  let l:current_tab = tabpagenr()
  let l:current_win = winnr()
  
  for l:tab in range(1, tabpagenr('$'))
    execute 'tabnext ' . l:tab
    let l:tab_info = {}
    
    for l:win in range(1, winnr('$'))
      execute l:win . 'wincmd w'
      let l:bufname = bufname('%')
      let l:filetype = &filetype
      
      if l:bufname =~# 'NERD_tree_' || l:filetype ==# 'nerdtree'
        " Capture NERDTree Root
        let l:root = ''
        if exists('b:NERDTree')
            try
                let l:root = b:NERDTree.root.path.str()
            catch
            endtry
        endif

        let l:tab_info[l:win] = {
              \ 'type': 'nerdtree',
              \ 'root': l:root,
              \ 'width': winwidth(0),
              \ 'height': winheight(0),
              \ 'position': l:win == 1 ? 'left' : 'right'
              \ }
      elseif l:bufname =~# '__Tagbar__' || l:filetype ==# 'tagbar'
        let l:tab_info[l:win] = {
              \ 'type': 'tagbar',
              \ 'width': winwidth(0),
              \ 'position': l:win == winnr('$') ? 'right' : 'left'
              \ }
      elseif &buftype ==# 'quickfix'
        let l:tab_info[l:win] = {
              \ 'type': 'quickfix',
              \ 'height': winheight(0)
              \ }
      elseif getloclist(0, {'size': 0}).size > 0
        let l:tab_info[l:win] = {
              \ 'type': 'loclist',
              \ 'height': winheight(0)
              \ }
      elseif &buftype ==# 'terminal'
        let l:tab_info[l:win] = {
              \ 'type': 'terminal',
              \ 'width': winwidth(0),
              \ 'height': winheight(0)
              \ }
      endif
    endfor
    
    if !empty(l:tab_info)
      let l:special_windows[l:tab] = l:tab_info
    endif
  endfor
  
  " Restore original position
  execute 'tabnext ' . l:current_tab
  execute l:current_win . 'wincmd w'
  
  return l:special_windows
endfunction

function! s:restore_special_windows(session_file) abort
  " Check if special window restoration is enabled
  if !get(g:, 'vim_sessions_restore_special_windows', 1)
    return
  endif
  
  let l:special_file = a:session_file . '.special'
  if !filereadable(l:special_file)
    return
  endif
  
        try
    let l:special_windows = eval(join(readfile(l:special_file), "\n"))
    
    for [l:tab, l:tab_info] in items(l:special_windows)
      execute 'tabnext ' . l:tab
      
      for [l:win, l:win_info] in items(l:tab_info)
        if l:win_info.type ==# 'nerdtree'
          if exists(':NERDTree') && exists('g:NERDTreeWinSize')
            let l:old_size = g:NERDTreeWinSize
            let g:NERDTreeWinSize = l:win_info.width
            
            " Restore specific root if saved, otherwise toggle default
            if !empty(get(l:win_info, 'root', ''))
                execute 'NERDTree ' . fnameescape(l:win_info.root)
            else
                execute 'NERDTreeToggle'
            endif
            
            " Move to correct position if needed
            if l:win_info.position ==# 'right' && winnr() == 1
               execute 'wincmd L'
            endif
            
            let g:NERDTreeWinSize = l:old_size
          endif
        elseif l:win_info.type ==# 'tagbar'
          " Try to restore Tagbar
          if exists(':TagbarOpen')
            execute 'TagbarOpen'
            execute 'vertical resize ' . l:win_info.width
          endif
        elseif l:win_info.type ==# 'quickfix'
          " Restore quickfix window
          execute 'copen ' . l:win_info.height
        elseif l:win_info.type ==# 'loclist'
          " Restore location list
          execute 'lopen ' . l:win_info.height
        elseif l:win_info.type ==# 'terminal'
          " Terminal windows are handled by the session itself
          " Just resize if needed
          if has_key(l:win_info, 'width') && has_key(l:win_info, 'height')
            execute 'resize ' . l:win_info.height
            execute 'vertical resize ' . l:win_info.width
          endif
        endif
      endfor
    endfor
  catch
    " Ignore errors in special window restoration
  endtry
endfunction

" Session operations {{{1
" Improved: Close special windows by scanning backwards (prevents index shifting)
function! s:close_special_windows(special_windows) abort
  let l:current_tab = tabpagenr()
  
  " Process each tab
  for l:tab in range(1, tabpagenr('$'))
    execute 'tabnext ' . l:tab
    
    " Iterate BACKWARDS from the last window to the first
    " This is crucial: closing windows changes indices, so we must go in reverse
    for l:win in reverse(range(1, winnr('$')))
      execute l:win . 'wincmd w'
      let l:bufname = bufname('%')
      let l:filetype = &filetype
      
      " Detect and forcefully close special windows
      if l:bufname =~# 'NERD_tree_' || l:filetype ==# 'nerdtree' ||
            \ l:bufname =~# '__Tagbar__' || l:filetype ==# 'tagbar' ||
            \ &buftype ==# 'quickfix' || getloclist(0, {'size': 0}).size > 0
            
        try
          close
        catch
          " Ignore close errors (e.g. if it's the last window)
        endtry
      endif
    endfor
  endfor
  
  " Restore focus to original tab
  execute 'tabnext ' . l:current_tab
endfunction

" Updated save function to implement the Close -> Save -> Restore workflow
function! vimsessions#save(name, bang) abort
  let l:original = &sessionoptions
  set sessionoptions=blank,buffers,curdir,folds,help,options,tabpages,winsize,winpos
  if g:vim_sessions_include_tabpages | set sessionoptions+=tabpages | endif
  if g:vim_sessions_include_buffers | set sessionoptions+=buffers | endif
  
  try
    let l:filename = vimsessions#encode_path(vimsessions#get_session_name())
    let l:session_file = vimsessions#session_file(l:filename)
    
    " Determine nickname (logic unchanged)
    if empty(a:name)
      let l:nicknames = vimsessions#load_nicknames()
      let l:existing_nickname = get(l:nicknames, fnamemodify(l:session_file, ':t:r'), '')
      let l:nickname = !empty(l:existing_nickname) ? l:existing_nickname : (empty(expand('%:t')) ? 'session' : expand('%:t'))
    else
      let l:nickname = a:name
    endif
    
    " 1. Analyze and Close special windows to ensure clean session file
    let l:restore_enabled = get(g:, 'vim_sessions_restore_special_windows', 1)
    let l:special_windows = s:save_special_windows()
    
    if l:restore_enabled
      call s:close_special_windows(l:special_windows)
    endif
    
    " 2. Generate clean session file
    try
      execute 'mksession! ' . fnameescape(l:session_file)
    catch
      " If save fails, ensure we still restore windows so user doesn't lose them
      if l:restore_enabled | call s:restore_special_windows(l:session_file) | endif
      echohl ErrorMsg | echo 'Debug: mksession failed: ' . v:exception | echohl None
      throw v:exception
    endtry
    
    call vimsessions#set_nickname(l:session_file, l:nickname)
    
    " 3. Save special window data and Restore windows for the user
    if !empty(l:special_windows)
      call writefile([string(l:special_windows)], l:session_file . '.special')
      
      " Immediately restore windows so the editor state looks unchanged to the user
      if l:restore_enabled
        call s:restore_special_windows(l:session_file)
      endif
    endif
    
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

function! vimsessions#load(name) abort
  if empty(a:name)
    let l:filename = vimsessions#encode_path(vimsessions#get_session_name())
    let l:path = vimsessions#session_file(l:filename)
    
    if !filereadable(l:path)
      echohl WarningMsg
      echo 'There is no session associated with this directory: ' . getcwd()
      echohl None
      return
    endif
  else
    let l:filename = vimsessions#find_by_nickname(a:name)
    if empty(l:filename)
      echohl WarningMsg
      echo 'Session not found: ' . a:name
      echohl None
      return
    endif
    let l:path = vimsessions#session_file(l:filename)
  endif
  
  try
    execute 'source ' . fnameescape(l:path)
    
    " Restore special windows after a short delay
    call timer_start(100, {-> s:restore_special_windows(l:path)})
    
    echohl MoreMsg
    echo 'Loaded session: ' . (empty(a:name) ? fnamemodify(l:path, ':t:r') : a:name)
    echohl None
  catch
    echohl ErrorMsg
    echo 'Failed to load session: ' . v:exception
    echohl None
  endtry
endfunction

function! vimsessions#delete(name) abort
  let l:filename = empty(a:name) ? vimsessions#encode_path(vimsessions#get_session_name()) : vimsessions#find_by_nickname(a:name)
  if empty(l:filename)
    echohl WarningMsg
    echo 'Session not found: ' . (empty(a:name) ? 'current directory' : a:name)
    echohl None
    return
  endif
  
  let l:path = vimsessions#session_file(l:filename)
  if !filereadable(l:path)
    echohl WarningMsg
    echo 'Session file not found: ' . fnamemodify(l:path, ':t')
    echohl None
    return
  endif
  
  if delete(l:path) == 0
    " Remove special windows file if exists
    let l:special_file = l:path . '.special'
    if filereadable(l:special_file)
      call delete(l:special_file)
    endif
    
    " Remove nickname if exists
    let l:nicknames = vimsessions#load_nicknames()
    if has_key(l:nicknames, l:filename)
      unlet l:nicknames[l:filename]
      call vimsessions#save_nicknames(l:nicknames)
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

function! vimsessions#list() abort
  let l:files = sort(glob(g:vim_sessions_dir . '/*.vim', 0, 1))
  if empty(l:files)
    echohl WarningMsg
    echo 'No sessions found in ' . g:vim_sessions_dir
    echohl None
    return
  endif
  
  echo 'Available sessions in ' . g:vim_sessions_dir . ':'
  echo ''
  
  let l:nicknames = vimsessions#load_nicknames()
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
function! s:delete_session() abort
  let [l:nickname, l:filename] = s:get_session_info()
  if !empty(l:filename)
    if confirm('Delete session "' . l:nickname . '"?', "&Yes\n&No", 2) == 1
      call vimsessions#delete(l:filename)

      " Enable modification briefly to remove the line
      setlocal modifiable
      delete _
      setlocal nomodifiable

      echo 'Deleted session: ' . l:nickname
    endif
  endif
endfunction

function! vimsessions#edit() abort
  let l:files = sort(glob(g:vim_sessions_dir . '/*.vim', 0, 1))
  if empty(l:files)
    echohl WarningMsg
    echo 'No sessions found in ' . g:vim_sessions_dir
    echohl None
    return
  endif
  
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile filetype=sessions
  
  " Add header
  call setline(1, [
        \ '" vim-sessions - Interactive Session Editor',
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
  let l:nicknames = vimsessions#load_nicknames()
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
  " Robust regex extraction for: Nickname | Filename | ...
  let l:match = matchlist(l:line, '^\s*\(.\{-}\)\s*|\s*\(.\{-}\)\s*|')
  
  if len(l:match) < 3
    return ['', '']
  endif
  
  let l:nickname = l:match[1]
  let l:filename = l:match[2]
  
  " Clean extension
  if l:filename =~# '\.vim$'
    let l:filename = fnamemodify(l:filename, ':r')
  endif
  
  return [l:nickname, l:filename]
endfunction

function! s:load_session() abort
  let [l:nickname, l:filename] = s:get_session_info()
  if !empty(l:filename)
    " Close session editor
    close
    " wipe buffers to ensure clean session load
    silent! %bdelete!
    call vimsessions#load(l:filename)
  endif
endfunction

function! s:rename_session() abort
  let [l:old_nickname, l:filename] = s:get_session_info()
  if empty(l:filename)
    return
  endif
  
  let l:new_nickname = input('Edit nickname: ', l:old_nickname)
  if !empty(l:new_nickname) && l:new_nickname !=# l:old_nickname
    let l:session_file = vimsessions#session_file(l:filename)
    call vimsessions#set_nickname(l:session_file, l:new_nickname)
    
    " Update the line
    let l:parts = split(getline('.'), ' | ')
    let l:new_line = printf('%-30s | %s | %s | %s', l:new_nickname, l:parts[1], l:parts[2], l:parts[3])
    call setline('.', l:new_line)
    
    echo 'Renamed session to: ' . l:new_nickname
  endif
endfunction

" Command completion {{{1
function! vimsessions#complete(ArgLead, CmdLine, CursorPos) abort
  let l:candidates = []
  let l:nicknames = vimsessions#load_nicknames()
  
  " Add nicknames
  for l:nickname in values(l:nicknames)
    if l:nickname =~# '^' . escape(a:ArgLead, '.*^$[]')
      call add(l:candidates, l:nickname)
    endif
  endfor
  
  " Add filenames
  for l:file in glob(g:vim_sessions_dir . '/*.vim', 0, 1)
    let l:filename = fnamemodify(l:file, ':t:r')
    if l:filename =~# '^' . escape(a:ArgLead, '.*^$[]')
      call add(l:candidates, l:filename)
    endif
  endfor
  
  return sort(uniq(l:candidates))
endfunction

" vim:foldmethod=marker:foldlevel=0
