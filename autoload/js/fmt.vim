" Copyright 2011 The Go Authors. All rights reserved.
" Use of this source code is governed by a BSD-style
" license that can be found in the LICENSE file.
"
" fmt.vim: Vim command to format js files with prettier

if !exists("g:js_fmt_command")
  let g:js_fmt_command = "prettier"
endif

if !exists('g:js_fmt_fail_silently')
  let g:js_fmt_fail_silently = 0
endif

if !exists('g:js_fmt_options')
  let g:js_fmt_options = ''
endif

if !exists("g:js_fmt_experimental")
  let g:js_fmt_experimental = 0
endif

"  we have those problems :
"  http://stackoverflow.com/questions/12741977/prevent-vim-from-updating-its-undo-tree
"  http://stackoverflow.com/questions/18532692/golang-formatter-and-vim-how-to-destroy-history-record?rq=1
"
"  The below function is an improved version that aims to fix all problems.
"  it doesn't undo changes and break undo history.  If you are here reading
"  this and have VimL experience, please look at the function for
"  improvements, patches are welcome :)
function! js#fmt#Format() abort
  if g:js_fmt_experimental == 1
    " Using winsaveview to save/restore cursor state has the problem of
    " closing folds on save:
    "   https://github.com/fatih/vim-go/issues/502
    " One fix is to use mkview instead. Unfortunately, this sometimes causes
    " other bad side effects:
    "   https://github.com/fatih/vim-go/issues/728
    " and still closes all folds if foldlevel>0:
    "   https://github.com/fatih/vim-go/issues/732
    let l:curw = {}
    try
      mkview!
    catch
      let l:curw = winsaveview()
    endtry

    " save our undo file to be restored after we are done. This is needed to
    " prevent an additional undo jump due to BufWritePre auto command and also
    " restore 'redo' history because it's getting being destroyed every
    " BufWritePre
    let tmpundofile = tempname()
    exe 'wundo! ' . tmpundofile
  else
    " Save cursor position and many other things.
    let l:curw = winsaveview()
  endif

  " Write current unsaved buffer to a temp file
  let l:tmpname = tempname()
  call writefile(js#util#GetLines(), l:tmpname)
  if js#util#IsWin()
    let l:tmpname = tr(l:tmpname, '\', '/')
  endif

  let bin_name = g:js_fmt_command

  let out = js#fmt#run(bin_name, l:tmpname, expand('%'))
  if js#util#ShellError() == 0
    call js#fmt#update_file(l:tmpname, expand('%'))
  elseif g:js_fmt_fail_silently == 0
    let errors = s:parse_errors(expand('%'), out)
    call s:show_errors(errors)
  endif

  " We didn't use the temp file, so clean up
  " call delete(l:tmpname)

  if g:js_fmt_experimental == 1
    " restore our undo history
    silent! exe 'rundo ' . tmpundofile
    call delete(tmpundofile)

    " Restore our cursor/windows positions, folds, etc.
    if empty(l:curw)
      silent! loadview
    else
      call winrestview(l:curw)
    endif
  else
    " Restore our cursor/windows positions.
    call winrestview(l:curw)
  endif
endfunction

" update_file updates the target file with the given formatted source
function! js#fmt#update_file(source, target)
  " remove undo point caused via BufWritePre
  try | silent undojoin | catch | endtry

  let old_fileformat = &fileformat
  if exists("*getfperm")
    " save file permissions
    let original_fperm = getfperm(a:target)
  endif

  call rename(a:source, a:target)

  " restore file permissions
  if exists("*setfperm") && original_fperm != ''
    call setfperm(a:target , original_fperm)
  endif

  " reload buffer to reflect latest changes
  silent! edit!

  let &fileformat = old_fileformat
  let &syntax = &syntax

  " clean up previous location list
  let l:listtype = "locationlist"
  call js#list#Clean(l:listtype)
  call js#list#Window(l:listtype)
endfunction

" run runs the gofmt/goimport command for the given source file and returns
" the the output of the executed command. Target is the real file to be
" formated.
function! js#fmt#run(bin_name, source, target)
  let cmd = s:fmt_cmd(a:bin_name, a:source, a:target)

  let command = join(cmd, " ")
  " call js#util#EchoWarning(printf("cmd %s", command))

  " execute our command...
  let out = js#util#System(command)

  return out
endfunction

" fmt_cmd returns a dict that contains the command to execute gofmt (or
" goimports). args is dict with
function! s:fmt_cmd(bin_name, source, target)
  " check if the user has installed command binary.
  " For example if it's goimports, let us check if it's installed,
  " if not the user get's a warning via js#path#CheckBinPath()
  let bin_path = js#path#CheckBinPath(a:bin_name)
  if empty(bin_path)
    return
  endif

  " start constructing the command
  let cmd = [bin_path]
  call add(cmd, "--write")
  call extend(cmd, split(g:js_fmt_options, " "))

  call add(cmd, a:source)
  return cmd
endfunction

" parse_errors parses the given errors and returns a list of parsed errors
function! s:parse_errors(filename, content) abort
  let splitted = split(a:content, '\n')

  " list of errors to be put into location list
  let errors = []
  for line in splitted
    " XXX TODO FIXME
    " let tokens = matchlist(line, '^\(.\{-}\):\(\d\+\):\(\d\+\)\s*\(.*\)')
    let tokens = matchlist(line, '^\(.\{-}\):\(.\{-}\)(\(\d\+\):\(\d\+\))')
    if !empty(tokens)
      " XXX TODO FIXME
      " call add(errors,{
      "       \"filename": a:filename,
      "       \"lnum":     tokens[2],
      "       \"col":      tokens[3],
      "       \"text":     tokens[4],
      "       \ })
      call add(errors,{
            \"filename": a:filename,
            \"lnum":     tokens[3],
            \"col":      tokens[4],
            \"text":     tokens[2],
            \ })
    endif
  endfor

  return errors
endfunction

" show_errors opens a location list and shows the given errors. If the given
" errors is empty, it closes the the location list
function! s:show_errors(errors) abort
  let l:listtype = "locationlist"
  if !empty(a:errors)
    call js#list#Populate(l:listtype, a:errors, 'Format')
    echohl Error | echomsg "prettier returned error" | echohl None
  endif

  " this closes the window if there are no errors or it opens
  " it if there is any
  call js#list#Window(l:listtype, len(a:errors))
endfunction

function! js#fmt#ToggleFmtAutoSave() abort
  if get(g:, "js_fmt_autosave", 1)
    let g:js_fmt_autosave = 0
    call js#util#EchoProgress("auto fmt disabled")
    return
  end

  let g:js_fmt_autosave = 1
  call js#util#EchoProgress("auto fmt enabled")
endfunction

" vim: sw=2 ts=2 et
