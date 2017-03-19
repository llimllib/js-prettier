## js-prettier

js-prettier is a simple vim script to run the [prettier](https://github.com/jlongster/prettier/)
command on save, show errors if they appear, and not hose your work if they do.

js-prettier is ripped directly from the wonderful work in https://github.com/fatih/vim-go, 
which is unfortunately encumbered with a confusing license. I am not yet sure how this code
is licensed, but I'd like to BSD it. For now, use at your own risk.

## Install

*  [Vundle](https://github.com/gmarik/vundle)
  * `Plugin 'llimllib/js-prettier'`
  
## Usage

Add this line to your .vimrc to format your javascript files on save:

`autocmd BufWritePre *.js call js#fmt#Format()`

Otherwise, just bind `call js#fmt#Format()` to your preferred key mapping. Here's an example,
binding it to `<leader>p` only in javascript fies:

`au FileType javascript nnoremap <leader>p :call js#fmt#Format()<CR>`
