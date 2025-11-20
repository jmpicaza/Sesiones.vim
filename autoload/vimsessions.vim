" ============================================================================
" File: autoload/vimsessions.vim
" Description: Enhanced session management with special window support
" Author: jmpicaza
" Version: 2.2
" License: MIT
" ============================================================================

" Session filename generation {{{1
function! vimsessions#get_session_name() abort
  let l:current_file = expand('%:p')
  return empty(l:current_file) ? getcwd() : l:current_file
endfunction

function! vimsessions#encode_path(path) abort
  let l:safe = substitute(resolve(expand(a:path)), '^[/\\]*', '', '')
  " Use % as separator as requested
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
  
  " Sanitize user-provided names (allow % for paths)
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
      
      " Detect special windows and capture critical metadata (like Roots)
      if l:bufname =~# 'NERD_tree_' || l:filetype ==# 'nerdtree'
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
              \ 'width': winwidth(0)
              \ }
      elseif &buftype ==# 'quickfix'
        let l:tab_info[l:win] = {
              \ 'type': 'quickfix',
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
  if !get(g:, 'vim_sessions_restore_special_windows', 1)
    return
  endif
  
  let l:special_file = a:session_file . '.special'
  if !filereadable(l:special_file)
    return
  endif
  
  try
    let l:special_windows = eval(join(readfile(l:special_file), "\n"))
    
    " Walk through the restored windows and re-initialize plugins if needed
    for [l:tab, l:tab_info] in items(l:special_windows)
      execute 'tabnext ' . l:tab
      
      for [l:win, l:win_info] in items(l:tab_info)
        " Ensure the window exists (mksession restored the split)
        if winnr('$') < l:win | continue | endif
        execute l:win . 'wincmd w'
        
        if l:win_info.type ==# 'nerdtree'
          " If mksession loaded a text buffer or empty buffer, replace it with real NERDTree
          if exists(':NERDTree')
             if !empty(get(l:win_info, 'root', ''))
                execute 'NERDTree ' . fnameescape(l:win_info.root)
             else
                execute 'NERDTreeToggle'
             endif
             
             " Restore size
             if has_key(l:win_info, 'width')
                execute 'vertical resize ' . l:win_info.width
             endif
          endif
        elseif l:win_info.type ==# 'tagbar' && exists(':TagbarOpen')
            execute 'TagbarOpen'
        elseif l:win_info.type ==# 'quickfix'
            execute 'copen ' . get(l:win_info, 'height', 10)
        endif
      endfor
    endfor
  catch
    " Ignore restoration errors
  endtry
endfunction

" Session operations {{{1
function! vimsessions#save(name, bang) abort
  " Configure options: Exclude 'blank' to avoid ghost windows, exclude 'options' for cleanliness
  let l:original = &sessionoptions
  set sessionoptions=buffers,curdir,folds,help,tabpages,winsize,winpos
  if g:vim_sessions_include_tabpages | set sessionoptions+=tabpages | endif
  if g:vim_sessions_include_buffers | set sessionoptions+=buffers | endif
  
  try
    let l:filename = vimsessions#encode_path(vimsessions#get_session_name())
    let l:session_file = vimsessions#session_file(l:filename)
    
    " Nickname logic
    if empty(a:name)
      let l:nicknames = vimsessions#load_nicknames()
      let l:existing_nickname = get(l:nicknames, fnamemodify(l:session_file, ':t:r'), '')
      let l:nickname = !empty(l:existing_nickname) ? l:existing_nickname : (empty(expand('%:t')) ? 'session' : expand('%:t'))
    else
      let l:nickname = a:name
    endif
    
    " 1. Snapshot Plugin State (NERDTree root, etc)
    let l:special_windows = s:save_special_windows()
    
    " 2. Save Session (Snapshot layout exactly as is)
    execute 'mksession! ' . fnameescape(l:session_file)
    
    " 3. Save Sidecar Metadata
    call vimsessions#set_nickname(l:session_file, l:nickname)
    if !empty(l:special_windows)
      call writefile([string(l:special_windows)], l:session_file . '.special')
    endif
    
    echohl MoreMsg
    echo 'Saved session: ' . l:nickname
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
      echohl WarningMsg | echo 'No session found for directory.' | echohl None
      return
    endif
  else
    let l:filename = vimsessions#find_by_nickname(a:name)
    if empty(l:filename)
      echohl WarningMsg | echo 'Session not found: ' . a:name | echohl None
      return
    endif
    let l:path = vimsessions#session_file(l:filename)
  endif
  
  try
    " 1. Wipe current buffers to prevent conflicts (Clean Slate)
    silent! %bdelete!
    
    " 2. Load the standard Vim session
    execute 'source ' . fnameescape(l:path)
    
    " 3. Re-initialize plugins based on saved metadata
    call s:restore_special_windows(l:path)
    
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
    echohl WarningMsg | echo 'Session not found.' | echohl None
    return
  endif
  
  let l:path = vimsessions#session_file(l:filename)
  if delete(l:path) == 0
    let l:special_file = l:path . '.special'
    if filereadable(l:special_file) | call delete(l:special_file) | endif
    
    let l:nicknames = vimsessions#load_nicknames()
    if has_key(l:nicknames, l:filename)
      unlet l:nicknames[l:filename]
      call vimsessions#save_nicknames(l:nicknames)
    endif
    
    echohl MoreMsg | echo 'Deleted session: ' . l:filename | echohl None
  else
    echohl ErrorMsg | echo 'Failed to delete session.' | echohl None
  endif
endfunction

function! vimsessions#list() abort
  let l:files = sort(glob(g:vim_sessions_dir . '/*.vim', 0, 1))
  if empty(l:files)
    echo 'No sessions found.'
    return
  endif
  
  echo 'Available sessions:'
  echo ''
  let l:nicknames = vimsessions#load_nicknames()
  for l:file in l:files
    let l:filename = fnamemodify(l:file, ':t:r')
    let l:nickname = get(l:nicknames, l:filename, '')
    let l:display = empty(l:nickname) ? l:filename : l:nickname . ' (' . l:filename . ')'
    echo printf('  %-40s', l:display)
  endfor
endfunction

" Interactive session editor {{{1
function! vimsessions#edit() abort
  let l:files = sort(glob(g:vim_sessions_dir . '/*.vim', 0, 1))
  if empty(l:files)
    echo 'No sessions found.'
    return
  endif
  
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile filetype=sessions
  
  call setline(1, ['" vim-sessions - Interactive Session Editor', '" ', '" Instructions:', '"   <Enter> - Load', '"   dd      - Delete', '"   q       - Quit', '" ', '" Sessions:', '" ---------'])
  
  let l:nicknames = vimsessions#load_nicknames()
  let l:line_num = 10
  for l:file in l:files
    let l:filename = fnamemodify(l:file, ':t')
    let l:rawname = fnamemodify(l:file, ':t:r')
    let l:nickname = get(l:nicknames, l:rawname, l:rawname)
    let l:size = printf('%6s', getfsize(l:file) . 'B')
    let l:time = strftime('%Y-%m-%d %H:%M', getftime(l:file))
    
    call setline(l:line_num, printf('%-30s | %-30s | %s | %s', l:nickname, l:filename, l:size, l:time))
    let l:line_num += 1
  endfor
  
  nnoremap <buffer><silent> <CR> :call <SID>load_session()<CR>
  nnoremap <buffer><silent> dd :call <SID>delete_session()<CR>
  nnoremap <buffer><silent> r :call <SID>rename_session()<CR>
  nnoremap <buffer><silent> q :close<CR>
  
  call cursor(10, 1)
endfunction

function! s:get_session_info() abort
  let l:line = getline('.')
  " Robust regex for parsing
  let l:match = matchlist(l:line, '^\s*\(.\{-}\)\s*|\s*\(.\{-}\)\s*|')
  if len(l:match) < 3 | return ['', ''] | endif
  
  let l:nickname = trim(l:match[1])
  let l:filename = trim(l:match[2])
  if l:filename =~# '\.vim$' | let l:filename = fnamemodify(l:filename, ':r') | endif
  return [l:nickname, l:filename]
endfunction

function! s:load_session() abort
  let [l:nickname, l:filename] = s:get_session_info()
  if !empty(l:filename)
    close
    silent! %bdelete!
    call vimsessions#load(l:filename)
  endif
endfunction

function! s:delete_session() abort
  let [l:nickname, l:filename] = s:get_session_info()
  if !empty(l:filename)
    if confirm('Delete "' . l:nickname . '"?', "&Yes\n&No", 2) == 1
      call vimsessions#delete(l:filename)
      setlocal modifiable
      delete _
      setlocal nomodifiable
    endif
  endif
endfunction

function! s:rename_session() abort
  let [l:old_nickname, l:filename] = s:get_session_info()
  if empty(l:filename) | return | endif
  
  let l:new_nickname = input('New nickname: ', l:old_nickname)
  if !empty(l:new_nickname) && l:new_nickname !=# l:old_nickname
    let l:session_file = vimsessions#session_file(l:filename)
    call vimsessions#set_nickname(l:session_file, l:new_nickname)
    let l:parts = split(getline('.'), ' | ')
    call setline('.', printf('%-30s | %s | %s | %s', l:new_nickname, l:parts[1], l:parts[2], l:parts[3]))
  endif
endfunction

function! vimsessions#complete(ArgLead, CmdLine, CursorPos) abort
  let l:candidates = []
  let l:nicknames = vimsessions#load_nicknames()
  call extend(l:candidates, values(l:nicknames))
  for l:file in glob(g:vim_sessions_dir . '/*.vim', 0, 1)
    call add(l:candidates, fnamemodify(l:file, ':t:r'))
  endfor
  return filter(sort(uniq(l:candidates)), 'v:val =~# "^" . escape(a:ArgLead, ".*^$[]")')
endfunction

" vim:foldmethod=marker:foldlevel=1
