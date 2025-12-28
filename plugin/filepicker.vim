" Use Ranger/LF/Yazi/NNN to select and open file(s) in (Neo)Vim.
"
" You need to either
" - copy the content of this file to your ~/.vimrc resp. ~/.config/nvim/init.vim,
" - or put it into ~/.vim/plugin respectively ~/.config/nvim/plugin,
" - or source this file directly:
"
"     let s:fp = "/path/to/filepicker.vim"
"     if filereadable(s:fp) | exec "source" s:fp | endif
"     unlet s:fp
"
" FilePicker opens a given path, defaulting to that of the currently open file.
" You may also like to assign a key to this command:
"
" A mapping to - is provided below that falls back to built-in Netrw if none of
" Ranger/LF/Yazi/NNN is available.
"
" Options:
" - g:filepicker_prefer: command name or full path (e.g. 'lf', 'ranger', '/usr/bin/ranger')
" - g:filepicker_args: Dict of extra arguments per picker, list or string.
"     Example:
"       let g:filepicker_args = {
"         \ 'ranger': ['--choosedir=/tmp/dir'],   " extra per picker
"         \ '*': '--chooseflags something'        " default for all
"       \ }
" - g:filepicker_open: how to open the first selected file:
"     'drop' (default), 'edit', 'split', 'vsplit', 'tab', 'tabedit', 'tabdrop'
" - g:filepicker_hijack_netrw: 1 (default) to replace netrw directory buffers.
"
" Notes:
" - The picker is spawned with cwd set to the desired start directory. This avoids
"   reliance on positional path semantics across pickers.
" - For pickers that support selecting a specific file on start, we pass that file
"   explicitly (e.g. ranger --selectfile FILE). Otherwise, the cwd is used.

if &compatible || exists('g:loaded_filepicker') | finish | endif
let g:loaded_filepicker = 1

nnoremap <silent> <plug>(FilePicker) :<c-u>FilePicker<CR>

if !exists("g:no_plugin_maps") && !exists("g:no_filepicker_maps")
  if !hasmapto('<plug>(FilePicker)', 'n')
    nmap <silent> - <plug>(FilePicker)
  endif
endif

command! -nargs=? -bar -complete=dir FilePicker call filepicker#FilePicker(<q-args>)

if get(g:, 'filepicker_hijack_netrw', 1) && filepicker#PickerAvailable()
  if !exists('g:loaded_netrw')
    let g:loaded_netrw = 1
    let g:loaded_netrwPlugin = 1
  endif

  augroup FilePickerHijack
    autocmd!
    autocmd VimEnter * call filepicker#OnVimEnter()
    autocmd BufEnter * nested call filepicker#OnBufEnter()
    autocmd FileType netrw call filepicker#OnFileTypeNetrw()
  augroup END
endif

