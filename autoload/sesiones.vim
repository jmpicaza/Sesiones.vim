function! sesiones#_cwd_slug() abort
  let l:cwd = getcwd()
  " Make a short but stable name: cwd base + 8-char sha1
  if executable('sha1sum')
    let l:hash = systemlist("printf '%s' ".shellescape(l:cwd)." | sha1sum")[0][:7]
  else
    " Fallback: naive hash
    let l:hash = printf('%x', abs(str2nr(reltime()[1])))[-8:]
  endif
  return fnamemodify(l:cwd, ':t') . '-' . l:hash
endfunction

function! sesiones#_resolve_name(name) abort
  return empty(a:name) ? sesiones#_cwd_slug() : a:name
endfunction

function! sesiones#_sessionfile(name) abort
  let l:name = a:name
  " Sanitize filename
  let l:safe = substitute(l:name, '[^A-Za-z0-9._-]', '_', 'g')
  return g:sesiones_dir . '/' . l:safe . '.vim'
endfunction

function! sesiones#_tune_sessionopts() abort
  " Never persist :set options/mappings
  set sessionoptions-=options
  if g:sesiones_include_tabpages
    set sessionoptions+=tabpages
  else
    set sessionoptions-=tabpages
  endif
  if g:sesiones_include_buffers
    set sessionoptions+=buffers
  else
    set sessionoptions-=buffers
  endif
  " Common niceties
  set sessionoptions-=help
endfunction

function! sesiones#save(name, bang) abort
  call sesiones#_tune_sessionopts()
  let l:fname = sesiones#_sessionfile(sesiones#_resolve_name(a:name))
  if !a:bang && filereadable(l:fname)
    echohl WarningMsg | echom 'Session exists: '.l:fname.' (use :SessionSave! to overwrite)'
    echohl None
    return
  endif
  execute 'silent! mksession! ' . fnameescape(l:fname)
  echom 'Saved session: ' . l:fname
endfunction

function! sesiones#load(name) abort
  let l:name = sesiones#_resolve_name(a:name)
  let l:path = sesiones#_sessionfile(l:name)
  if !filereadable(l:path)
    " Try best match for this cwd
    let l:list = sesiones#_glob_sessions()
    if empty(l:list)
      echohl WarningMsg | echom 'No sessions in ' . g:sesiones_dir | echohl None
      return
    endif
    let l:path = l:list[0]
  endif
  execute 'silent! source ' . fnameescape(l:path)
  echom 'Loaded session: ' . l:path
endfunction

function! sesiones#delete(name) abort
  let l:path = sesiones#_sessionfile(sesiones#_resolve_name(a:name))
  if filereadable(l:path)
    call delete(l:path)
    echom 'Deleted session: ' . l:path
  else
    echohl WarningMsg | echom 'No such session: ' . l:path | echohl None
  endif
endfunction

function! sesiones#_glob_sessions() abort
  return sort(globpath(g:sesiones_dir, '*.vim', 0, 1), 'n')
endfunction

function! sesiones#list() abort
  let l:list = sesiones#_glob_sessions()
  if empty(l:list)
    echom 'No sessions in ' . g:sesiones_dir
    return
  endif
  echo 'Sessions:'
  for l:f in l:list
    echo '  ' . fnamemodify(l:f, ':t:r')
  endfor
endfunction
