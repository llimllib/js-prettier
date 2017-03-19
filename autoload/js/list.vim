if !exists("g:js_list_type")
  let g:js_list_type = ""
endif

" Window opens the list with the given height up to 10 lines maximum.
" Otherwise g:js_loclist_height is used. If no or zero height is given it
" closes the window
function! js#list#Window(listtype, ...) abort
  let l:listtype = js#list#Type(a:listtype)
  " we don't use lwindow to close the location list as we need also the
  " ability to resize the window. So, we are going to use lopen and lclose
  " for a better user experience. If the number of errors in a current
  " location list increases/decreases, cwindow will not resize when a new
  " updated height is passed. lopen in the other hand resizes the screen.
  if !a:0 || a:1 == 0
    if l:listtype == "locationlist"
      lclose
    else
      cclose
    endif
    return
  endif

  let height = get(g:, "js_list_height", 0)
  if height == 0
    " prevent creating a large location height for a large set of numbers
    if a:1 > 10
      let height = 10
    else
      let height = a:1
    endif
  endif

  if l:listtype == "locationlist"
    exe 'lopen ' . height
  else
    exe 'copen ' . height
  endif
endfunction


" Get returns the current list of items from the location list
function! js#list#Get(listtype) abort
  let l:listtype = js#list#Type(a:listtype)
  if l:listtype == "locationlist"
    return getloclist(0)
  else
    return getqflist()
  endif
endfunction

" Populate populate the location list with the given items
function! js#list#Populate(listtype, items, title) abort
  let l:listtype = js#list#Type(a:listtype)
  if l:listtype == "locationlist"
    call setloclist(0, a:items, 'r')

    " The last argument ({what}) is introduced with 7.4.2200:
    " https://github.com/vim/vim/commit/d823fa910cca43fec3c31c030ee908a14c272640
    if has("patch-7.4.2200") | call setloclist(0, [], 'a', {'title': a:title}) | endif
  else
    call setqflist(a:items, 'r')
    if has("patch-7.4.2200") | call setqflist([], 'a', {'title': a:title}) | endif
  endif
endfunction

function! js#list#PopulateWin(winnr, items) abort
  call setloclist(a:winnr, a:items, 'r')
endfunction

" Parse parses the given items based on the specified errorformat nad
" populates the location list.
function! js#list#ParseFormat(listtype, errformat, items, title) abort
  let l:listtype = js#list#Type(a:listtype)
  " backup users errorformat, will be restored once we are finished
  let old_errorformat = &errorformat

  " parse and populate the location list
  let &errorformat = a:errformat
  if l:listtype == "locationlist"
    lgetexpr a:items
    if has("patch-7.4.2200") | call setloclist(0, [], 'a', {'title': a:title}) | endif
  else
    cgetexpr a:items
    if has("patch-7.4.2200") | call setqflist([], 'a', {'title': a:title}) | endif
  endif

  "restore back
  let &errorformat = old_errorformat
endfunction

" Parse parses the given items based on the global errorformat and
" populates the location list.
function! js#list#Parse(listtype, items) abort
  let l:listtype = js#list#Type(a:listtype)
  if l:listtype == "locationlist"
    lgetexpr a:items
  else
    cgetexpr a:items
  endif
endfunction

" JumpToFirst jumps to the first item in the location list
function! js#list#JumpToFirst(listtype) abort
  let l:listtype = js#list#Type(a:listtype)
  if l:listtype == "locationlist"
    ll 1
  else
    cc 1
  endif
endfunction

" Clean cleans the location list
function! js#list#Clean(listtype) abort
  let l:listtype = js#list#Type(a:listtype)
  if l:listtype == "locationlist"
    lex []
  else
    cex []
  endif
endfunction

function! js#list#Type(listtype) abort
  if g:js_list_type == "locationlist"
    return "locationlist"
  elseif g:js_list_type == "quickfix"
    return "quickfix"
  else
    return a:listtype
  endif
endfunction

" vim: sw=2 ts=2 et
