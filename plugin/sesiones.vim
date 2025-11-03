"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" File:  "Sesiones.vim"
" URL:  http://vim.sourceforge.net/script.php?script_id=3542
" Version: 0.3
" Last Modified: 03/11/2025
" Author: jmpicaza at gmail dot com
" Description: Plugin for managing sesions the easy way
" 
"
"""""""""""""""""""""""""""""""""""""""""""
" Function for writing and loading sessions
"""""""""""""""""""""""""""""""""""""""""""
function! Sesiones(save_load)
	"echomsg "<F3> to save, <Shift-F3> to load, <Crtl-Shift-F3> to overwrite, d<F3> to delete"
	if exists('g:sesiones_path')
		let l:sesiones_path = g:sesiones_path
	else
		if has('unix') || has('macunix')
			let l:sesiones_path = $HOME . '/.vim/.vimSessions'
		else
			let l:sesiones_path = $VIM . '/_vimSessions'
			if has('win32')
				" MS-Windows
				if $USERPROFILE != ''
					let l:sesiones_path = $USERPROFILE . '/_vimSessions'
				endif
			endif
		endif
	endif

	" put the name of the file as the complete route to the file but changing / or \ and : to =+ and =-
	" fixed linux/mac compatibility
	let l:sesiones_path=substitute(expand(l:sesiones_path),"\\","\/","g") . "/" . substitute(substitute(expand('%:p').'.vim',"\/\\|\\","=+","g"),":","=-","")
	if (a:save_load == 0)
		if (filewritable(l:sesiones_path))
			echohl MoreMsg
			echomsg "WARNING: A session already exists for this file. Use <Crtl-Shift-F3> for Overwriting or <Shift-F3> to Load."
			echohl None
		else
			exe ":mksession " . l:sesiones_path
			echohl NonText
			echomsg "Session successfully saved in file: " . l:sesiones_path
			echohl None
		endif
	elseif (a:save_load == 1)
		if (filereadable(l:sesiones_path))
			exe "source " . l:sesiones_path
		else
			echohl ErrorMSG
			echomsg "WARNING: Does not exist a session associated to the file: " . expand('%')
			echohl None
		endif
	elseif (a:save_load == 2)
		if (filewritable(l:sesiones_path))
			exe ":mksession! " . l:sesiones_path
			echohl NonText
			echomsg "Session successfully overwritten"
			echohl None
		else
			echohl ErrorMSG
			echomsg "WARNING: Session does not exist. Use <F3> to create it"
			echohl None
		end
	elseif (a:save_load == 99)
		if (delete(l:sesiones_path))
			echohl ErrorMSG
			echomsg "ERROR: There was not possible to delete the file: " . l:sesiones_path
			echohl None
		else
			echohl NonText
			echomsg "Session deleted for this file."
			echohl None
		endif
	else
		echohl ErrorMSG
		echomsg "No valid option selected. Please review your code or command"
		echohl None
	endif
endfunction
nnoremap <F3> :call Sesiones(0)<ENTER>
nnoremap <S-F3> :call Sesiones(1)<ENTER>
nnoremap <C-S-F3> :call Sesiones(2)<ENTER>
nnoremap d<F3> :call Sesiones(99)<ENTER>
nmenu &Plugin.Se&ssions.&Save\ Session<Tab><F3>	:call Sesiones(0)<ENTER>
nmenu &Plugin.Se&ssions.&Load\ Session<Tab><S-F3>	:call Sesiones(1)<ENTER>
nmenu &Plugin.Se&ssions.&Overwrite\ Session<Tab><C-S-F3>	:call Sesiones(2)<ENTER>
nmenu &Plugin.Se&ssions.&Delete\ Session<Tab>d<F3>	:call Sesiones(99)<ENTER>

"EOF
