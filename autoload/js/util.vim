" PathSep returns the appropriate OS specific path separator.
function! js#util#PathSep() abort
  if js#util#IsWin()
    return '\'
  endif
  return '/'
endfunction

" PathListSep returns the appropriate OS specific path list separator.
function! js#util#PathListSep() abort
  if js#util#IsWin()
    return ";"
  endif
  return ":"
endfunction

" LineEnding returns the correct line ending, based on the current fileformat
function! js#util#LineEnding() abort
  if &fileformat == 'dos'
    return "\r\n"
  elseif &fileformat == 'mac'
    return "\r"
  endif

  return "\n"
endfunction

" Join joins any number of path elements into a single path, adding a
" Separator if necessary and returns the result
function! js#util#Join(...) abort
  return join(a:000, js#util#PathSep())
endfunction

" IsWin returns 1 if current OS is Windows or 0 otherwise
function! js#util#IsWin() abort
  let win = ['win16', 'win32', 'win64', 'win95']
  for w in win
    if (has(w))
      return 1
    endif
  endfor

  return 0
endfunction

function! js#util#has_job() abort
  " job was introduced in 7.4.xxx however there are multiple bug fixes and one
  " of the latest is 8.0.0087 which is required for a stable async API.
  return has('job') && has("patch-8.0.0087")
endfunction

" System runs a shell command. It will reset the shell to /bin/sh for Unix-like
" systems if it is executable.
function! js#util#System(str, ...) abort
  let l:shell = &shell
  if !js#util#IsWin() && executable('/bin/sh')
    let &shell = '/bin/sh'
  endif

  try
    let l:output = call('system', [a:str] + a:000)
    return l:output
  finally
    let &shell = l:shell
  endtry
endfunction

function! js#util#ShellError() abort
  return v:shell_error
endfunction

" StripPath strips the path's last character if it's a path separator.
" example: '/foo/bar/'  -> '/foo/bar'
function! js#util#StripPathSep(path) abort
  let last_char = strlen(a:path) - 1
  if a:path[last_char] == js#util#PathSep()
    return strpart(a:path, 0, last_char)
  endif

  return a:path
endfunction

" StripTrailingSlash strips the trailing slash from the given path list.
" example: ['/foo/bar/']  -> ['/foo/bar']
function! js#util#StripTrailingSlash(paths) abort
  return map(copy(a:paths), 'js#util#StripPathSep(v:val)')
endfunction

" Shelljoin returns a shell-safe string representation of arglist. The
" {special} argument of shellescape() may optionally be passed.
function! js#util#Shelljoin(arglist, ...) abort
  try
    let ssl_save = &shellslash
    set noshellslash
    if a:0
      return join(map(copy(a:arglist), 'shellescape(v:val, ' . a:1 . ')'), ' ')
    endif

    return join(map(copy(a:arglist), 'shellescape(v:val)'), ' ')
  finally
    let &shellslash = ssl_save
  endtry
endfunction

fu! js#util#Shellescape(arg)
  try
    let ssl_save = &shellslash
    set noshellslash
    return shellescape(a:arg)
  finally
    let &shellslash = ssl_save
  endtry
endf

" Shelllist returns a shell-safe representation of the items in the given
" arglist. The {special} argument of shellescape() may optionally be passed.
function! js#util#Shelllist(arglist, ...) abort
  try
    let ssl_save = &shellslash
    set noshellslash
    if a:0
      return map(copy(a:arglist), 'shellescape(v:val, ' . a:1 . ')')
    endif
    return map(copy(a:arglist), 'shellescape(v:val)')
  finally
    let &shellslash = ssl_save
  endtry
endfunction

" Returns the byte offset for line and column
function! js#util#Offset(line, col) abort
  if &encoding != 'utf-8'
    let sep = js#util#LineEnding()
    let buf = a:line == 1 ? '' : (join(getline(1, a:line-1), sep) . sep)
    let buf .= a:col == 1 ? '' : getline('.')[:a:col-2]
    return len(iconv(buf, &encoding, 'utf-8'))
  endif
  return line2byte(a:line) + (a:col-2)
endfunction
"
" Returns the byte offset for the cursor
function! js#util#OffsetCursor() abort
  return js#util#Offset(line('.'), col('.'))
endfunction

" Windo is like the built-in :windo, only it returns to the window the command
" was issued from
function! js#util#Windo(command) abort
  let s:currentWindow = winnr()
  try
    execute "windo " . a:command
  finally
    execute s:currentWindow. "wincmd w"
    unlet s:currentWindow
  endtry
endfunction

" TODO(arslan): I couldn't parameterize the highlight types. Check if we can
" simplify the following functions
"
" NOTE(arslan): echon doesn't work well with redraw, thus echo doesn't print
" even though we order it. However echom seems to be work fine.
function! js#util#EchoSuccess(msg)
  redraw | echohl Function | echom "js-prettier: " . a:msg | echohl None
endfunction

function! js#util#EchoError(msg)
  redraw | echohl ErrorMsg | echom "js-prettier: " . a:msg | echohl None
endfunction

function! js#util#EchoWarning(msg)
  redraw | echohl WarningMsg | echom "js-prettier: " . a:msg | echohl None
endfunction

function! js#util#EchoProgress(msg)
  redraw | echohl Identifier | echom "js-prettier: " . a:msg | echohl None
endfunction

function! js#util#EchoInfo(msg)
  redraw | echohl Debug | echom "js-prettier: " . a:msg | echohl None
endfunction

function! js#util#GetLines()
  let buf = getline(1, '$')
  if &encoding != 'utf-8'
    let buf = map(buf, 'iconv(v:val, &encoding, "utf-8")')
  endif
  if &l:fileformat == 'dos'
    " XXX: line2byte() depend on 'fileformat' option.
    " so if fileformat is 'dos', 'buf' must include '\r'.
    let buf = map(buf, 'v:val."\r"')
  endif
  return buf
endfunction

" vim: sw=2 ts=2 et
