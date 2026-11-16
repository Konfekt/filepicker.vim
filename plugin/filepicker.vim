" Use Yazi/LF/Ranger/NNN to select and open file(s) in (Neo)Vim.
" See :help filepicker for commands, mappings and options.

if &compatible || exists('g:loaded_filepicker') | finish | endif
let g:loaded_filepicker = 1

nnoremap <silent> <plug>(FilePicker) :<c-u>FilePicker<CR>

if !exists('g:no_plugin_maps') && !exists('g:no_filepicker_maps')
      \ && !hasmapto('<plug>(FilePicker)', 'n') && empty(maparg('-', 'n'))
  nmap <silent> - <plug>(FilePicker)
endif

command! -nargs=? -bar -complete=file FilePicker call filepicker#FilePicker(<q-args>)

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
