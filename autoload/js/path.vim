" initial_go_path is used to store the initial GOPATH that was set when Vim
" was started. It's used with :GoPathClear to restore the GOPATH when the user
" changed it explicitly via :GoPath. Initially it's empty. It's being set when
" :GoPath is used
let s:initial_go_path = ""

" GoPath sets or returns the current GOPATH. If no arguments are passed it
" echoes the current GOPATH, if an argument is passed it replaces the current
" GOPATH with it. If two double quotes are passed (the empty string in go),
" it'll clear the GOPATH and will restore to the initial GOPATH.
function! js#path#GoPath(...) abort
  " we have an argument, replace GOPATH
  if len(a:000)
    " clears the current manually set GOPATH and restores it to the
    " initial GOPATH, which was set when Vim was started.
    if len(a:000) == 1 && a:1 == '""'
      if !empty(s:initial_go_path)
        let $GOPATH = s:initial_go_path
        let s:initial_go_path = ""
      endif

      echon "vim-go: " | echohl Function | echon "GOPATH restored to ". $GOPATH | echohl None
      return
    endif

    echon "vim-go: " | echohl Function | echon "GOPATH changed to ". a:1 | echohl None
    let s:initial_go_path = $GOPATH
    let $GOPATH = a:1
    return
  endif

  echo js#path#Detect()
endfunction

" Default returns the default GOPATH. If there is a single GOPATH it returns
" it. For multiple GOPATHS separated with a the OS specific separator, only
" the first one is returned
function! js#path#Default() abort
  let go_paths = split($GOPATH, js#util#PathListSep())

  if len(go_paths) == 1
    return $GOPATH
  endif

  return go_paths[0]
endfunction

" HasPath checks whether the given path exists in GOPATH environment variable
" or not
function! js#path#HasPath(path) abort
  let go_paths = split($GOPATH, js#util#PathListSep())
  let last_char = strlen(a:path) - 1

  " check cases of '/foo/bar/' and '/foo/bar'
  if a:path[last_char] == js#util#PathSep()
    let withSep = a:path
    let noSep = strpart(a:path, 0, last_char)
  else
    let withSep = a:path . js#util#PathSep()
    let noSep = a:path
  endif

  let hasA = index(go_paths, withSep) != -1
  let hasB = index(go_paths, noSep) != -1
  return hasA || hasB
endfunction

" Detect returns the current GOPATH. If a package manager is used, such as
" Godeps, GB, it will modify the GOPATH so those directories take precedence
" over the current GOPATH. It also detects diretories whose are outside
" GOPATH.
function! js#path#Detect() abort
  let gopath = $GOPATH

  " don't lookup for godeps if autodetect is disabled.
  if !get(g:, "go_autodetect_gopath", 1)
    return gopath
  endif

  let current_dir = fnameescape(expand('%:p:h'))

  " TODO(arslan): this should be changed so folders or files should be
  " fetched from a customizable list. The user should define any new package
  " management tool by it's own.

  " src folder outside $GOPATH
  let src_root = finddir("src", current_dir .";")
  if !empty(src_root)
    let src_path = fnamemodify(src_root, ':p:h:h') . js#util#PathSep()

    " gb vendor plugin
    " (https://github.com/constabulary/gb/tree/master/cmd/gb-vendor)
    let gb_vendor_root = src_path . "vendor" . js#util#PathSep()
    if isdirectory(gb_vendor_root) && !js#path#HasPath(gb_vendor_root)
      let gopath = gb_vendor_root . js#util#PathListSep() . gopath
    endif

    if !js#path#HasPath(src_path)
      let gopath =  src_path . js#util#PathListSep() . gopath
    endif
  endif

  " Godeps
  let godeps_root = finddir("Godeps", current_dir .";")
  if !empty(godeps_root)
    let godeps_path = join([fnamemodify(godeps_root, ':p:h:h'), "Godeps", "_workspace" ], js#util#PathSep())

    if !js#path#HasPath(godeps_path)
      let gopath =  godeps_path . js#util#PathListSep() . gopath
    endif
  endif

  " Fix up the case where initial $GOPATH is empty,
  " and we end up with a trailing :
  let gopath = substitute(gopath, ":$", "", "")
  return gopath
endfunction


" BinPath returns the binary path of installed go tools.
function! js#path#BinPath() abort
  let bin_path = ""

  " check if our global custom path is set, if not check if $GOBIN is set so
  " we can use it, otherwise use $GOPATH + '/bin'
  if exists("g:go_bin_path")
    let bin_path = g:go_bin_path
  elseif $GOBIN != ""
    let bin_path = $GOBIN
    elseif $GOPATH != ""
        let bin_path = expand(js#path#Default() . "/bin/")
    else
        " could not find anything
    endif

    return bin_path
endfunction

" CheckBinPath checks whether the given binary exists or not and returns the
" path of the binary. It returns an empty string doesn't exists.
function! js#path#CheckBinPath(binpath) abort
    " remove whitespaces if user applied something like 'goimports   '
    let binpath = substitute(a:binpath, '^\s*\(.\{-}\)\s*$', '\1', '')
    " save off original path
    let old_path = $PATH

    " check if we have an appropriate bin_path
    let go_bin_path = js#path#BinPath()
    if !empty(go_bin_path)
        " append our GOBIN and GOPATH paths and be sure they can be found there...
        " let us search in our GOBIN and GOPATH paths
        let $PATH = go_bin_path . js#util#PathListSep() . $PATH
    endif

    " if it's in PATH just return it
    if executable(binpath)
        if exists('*exepath')
            let binpath = exepath(binpath)
        endif
        let $PATH = old_path
        return binpath
    endif

    " just get the basename
    let basename = fnamemodify(binpath, ":t")
    if !executable(basename)
        echom "vim-go: could not find '" . basename . "'. Run :GoInstallBinaries to fix it."
        " restore back!
        let $PATH = old_path
        return ""
    endif

    let $PATH = old_path

    return go_bin_path . js#util#PathSep() . basename
endfunction

" vim: sw=2 ts=2 et
