" Syntax highlighting for session editor buffer
" This makes the sessions editor more readable and user-friendly

if exists('b:current_syntax')
  finish
endif

" Comments (header and instructions)
syntax match sessionsComment '^".*'
highlight link sessionsComment Comment

" Session entry components: Nickname | Filename | Size | Date
syntax match sessionsNickname '^[^|"]\+' nextgroup=sessionsSeparator1
syntax match sessionsSeparator1 ' | ' contained nextgroup=sessionsFilename
syntax match sessionsFilename '[^|]\+' contained nextgroup=sessionsSeparator2
syntax match sessionsSeparator2 ' | ' contained nextgroup=sessionsSize
syntax match sessionsSize '[0-9]\+B\|     -' contained nextgroup=sessionsSeparator3  
syntax match sessionsSeparator3 ' | ' contained nextgroup=sessionsDate
syntax match sessionsDate '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}' contained

" Highlight different components
highlight link sessionsNickname Identifier
highlight link sessionsSeparator1 Delimiter
highlight link sessionsFilename Comment
highlight link sessionsSeparator2 Delimiter  
highlight link sessionsSize Number
highlight link sessionsSeparator3 Delimiter
highlight link sessionsDate String

" Special highlighting for section headers
syntax match sessionsHeader '^" \(Instructions\|Sessions\):'
syntax match sessionsSeparatorLine '^" -\+$'
highlight link sessionsHeader Title
highlight link sessionsSeparatorLine Title

let b:current_syntax = 'sessions'