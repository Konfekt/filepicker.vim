" Use Ranger/LF/Yazi/NNN to select and open file(s) in (Neo)Vim.
"
" You need to either
"
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

if &compatible || exists('g:loaded_filepicker') | finish | endif
let g:loaded_filepicker = 1

" Picker selection (prefer user choice, otherwise auto-detect; order: lf, ranger, yazi, nnn).
let s:_picker = ''
if exists('g:filepicker_prefer') && type(g:filepicker_prefer) == type('') && executable(g:filepicker_prefer)
  let s:_picker = g:filepicker_prefer
else
  if executable('lf')
    let s:_picker = 'lf'
  elseif executable('ranger')
    let s:_picker = 'ranger'
  elseif executable('yazi')
    let s:_picker = 'yazi'
  elseif executable('nnn')
    let s:_picker = 'nnn'
  else
    let s:_picker = ''
  endif
endif

nnoremap <silent> <plug>(FilePicker) :<c-u>FilePicker<CR>

if !exists("g:no_plugin_maps") && !exists("g:no_filepicker_maps")
  if !hasmapto('<plug>(FilePicker)', 'n')
    nmap <silent> - <plug>(FilePicker)
  endif
endif

if empty(s:_picker)
  " No external picker; netrw fallback.
  command! -nargs=? -bar -complete=dir FilePicker call <sid>Opendir(<q-args>)
  function! s:Opendir(dir) abort
    let path = a:dir
    if empty(path)
      let path = expand('%')
      if path =~# '^$\|^term:[\/][\/]'
        execute 'edit' '.'
      else
        let save_dir = getcwd()
        try
          call chdir(expand('%:p:h'))
          execute 'edit' expand('%:h')
          let pattern = '^\%(| \)*'.escape(expand('#:t'), '.*[]~\').'[/*|@=]\=\%($\|\s\)'
          call search(pattern, 'wc')
        finally
          call chdir(save_dir)
        endtry
      endif
    else
      execute 'edit' fnameescape(path)
    endif
  endfunction
  finish
endif

command! -nargs=? -bar -complete=dir FilePicker call FilePicker(<q-args>)

function! FilePicker(...) abort
  call s:save()
  " Use a fresh temp file for each run to avoid stale selections.
  let s:temp = tempname()

  " Resolve input path, defaulting to the current buffer's path or CWD.
  let user_path = (a:0 ? a:1 : '')
  if !empty(user_path)
    let user_path = fnamemodify(expand(user_path), ':p')
  endif

  let start_dir = ''
  let select_file = ''

  if !empty(user_path)
    if isdirectory(user_path)
      let start_dir = fnamemodify(user_path, ':p')
    elseif filereadable(user_path)
      let select_file = fnamemodify(user_path, ':p')
      let start_dir = fnamemodify(select_file, ':h')
    endif
  endif

  if empty(start_dir)
    let cur = expand('%:p')
    if filereadable(cur)
      let start_dir = fnamemodify(cur, ':h')
      if empty(select_file) | let select_file = cur | endif
    elseif isdirectory(cur) | let start_dir = cur
    else | let start_dir = getcwd()
    endif
  endif

  let cmd = s:build_cmd(s:_picker, start_dir, select_file)
  if empty(cmd)
    echohl WarningMsg | echom "[filepicker] No compatible picker found." | echohl None
    return
  endif

  call s:term(cmd)
endfunction

" Build the external picker command list for termopen/term_start or shell fallback.
function! s:build_cmd(picker, start_dir, select_file) abort
  let cmd = []
  if a:picker ==# 'lf'
    let cmd = ['lf', '-selection-path', s:temp]
  elseif a:picker ==# 'ranger'
    let cmd = ['ranger', '--choosefiles=' . s:temp]
    if !empty(a:select_file) && filereadable(a:select_file)
      call add(cmd, '--selectfile')
    endif
  elseif a:picker ==# 'yazi'
    let cmd = ['yazi', '--chooser-file=' . s:temp]
  elseif a:picker ==# 'nnn'
    let cmd = ['nnn', '-p', s:temp]
  endif
  if empty(cmd) | return [] | endif
  if !empty(a:select_file) && filereadable(a:select_file)
    call add(cmd, a:select_file)
  elseif !empty(a:start_dir)
    call add(cmd, a:start_dir)
  endif
  return cmd
endfunction

" Create a scratch buffer in any window showing {buf} so wiping it doesn't close
" the window/tabpage.
function! s:_keep_windows_open(buf) abort
  if !bufexists(a:buf) | return | endif
  let wins = []
  if exists('*win_findbuf')
    let wins = win_findbuf(a:buf)
  endif
  " If win_findbuf() is not available or returns nothing, at least protect the
  " current window if it shows the buffer.
  if empty(wins)
    if bufnr('%') == a:buf
      call s:_open_scratch_in_current_win()
    endif
    return
  endif
  for id in wins
    if win_gotoid(id)
      if bufnr('%') == a:buf
        call s:_open_scratch_in_current_win()
      endif
    endif
  endfor
endfunction

function! s:_open_scratch_in_current_win() abort
  keepalt enew
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
endfunction

" Script-local state: external picker presence and restoration context.
let s:_fp_prev_bufnr = -1

" Save context and prevent 'wipe' for the previous buffer while the picker runs.
function! s:save() abort
  let s:_fp_prev_bufnr      = bufnr('%')
  let s:_fp_prev_bufhidden  = getbufvar(s:_fp_prev_bufnr, '&bufhidden')
  let s:_fp_prev_hidden_opt = &hidden

  " Only adjust real file-like buffers that would be wiped when hidden.
  if s:_fp_prev_bufnr > 0
        \ && bufexists(s:_fp_prev_bufnr)
        \ && getbufvar(s:_fp_prev_bufnr, '&buftype') ==# ''
        \ && s:_fp_prev_bufhidden ==# 'wipe'
    " Ensure switching away from a modified buffer is allowed.
    set hidden
    " Prevent immediate wipe on hide; will restore later.
    call setbufvar(s:_fp_prev_bufnr, '&bufhidden', 'hide')
  endif
endfunction

let s:names = []
" Restore the previous window/buffer and original options.
function! s:restore() abort
  let prev_buf = get(s:, '_fp_prev_bufnr', -1)

  " Return to previous buffer if no files were selected.
  if prev_buf > 0 && bufexists(prev_buf) && bufnr('%') != prev_buf && empty(s:names)
    execute 'buffer' prev_buf
  endif

  " Restore original bufhidden for the previous buffer.
  if exists('s:_fp_prev_bufhidden') && prev_buf > 0 && bufexists(prev_buf)
    call setbufvar(prev_buf, '&bufhidden', s:_fp_prev_bufhidden)
  endif

  " Restore global 'hidden' if it was off.
  if exists('s:_fp_prev_hidden_opt') && !s:_fp_prev_hidden_opt
    set nohidden
  endif
endfunction

if has('nvim')
  " Neovim: run picker in a dedicated terminal buffer, wipe it on exit, then open files and restore.
  function! s:term(cmd) abort
    enew
    let term_buf = bufnr('%')
    setlocal nobuflisted
    call termopen(a:cmd, {'on_exit': function('s:_nvim_term_on_exit', [term_buf])})
    startinsert
  endfunction

  function! s:_nvim_term_on_exit(term_buf, job_id, code, event) abort
    " Slight defer to flush terminal I/O.
    call timer_start(1, function('s:_open_and_wipe', [a:term_buf]))
  endfunction

  function! s:_open_and_wipe(term_buf, ...) abort
    " Ensure the window/tab stays open even if the terminal was the only buffer.
    call s:_keep_windows_open(a:term_buf)
    if bufexists(a:term_buf)
      execute 'bwipeout!' a:term_buf
    endif
    call s:open()
    call s:restore()
  endfunction
else
  if has('terminal')
    function! s:term(cmd) abort
      " Start the terminal in the current window.
      let term_buf = term_start(a:cmd, {'curwin': 1, 'exit_cb': function('s:_vim_term_on_exit')})
      setlocal nobuflisted
    endfunction

    " Exit callback: schedule UI restore to the main loop to avoid E523.
    function! s:_vim_term_on_exit(job, status) abort
      " Map job object to its terminal buffer number.
      let term_buf = s:term_buf_for_job(a:job)

      " Replace the terminal buffer with a scratch in any window showing it so the
      " window/tabpage won't be closed when the buffer is wiped.
      if term_buf > 0 && bufexists(term_buf)
        call s:_keep_windows_open(term_buf)
        execute 'bwipeout!' term_buf
      endif

      " Continue with custom logic.
      call s:open()
      call s:restore()
    endfunction

    function! s:term_buf_for_job(job) abort
      for b in term_list()
        if term_getjob(b) is a:job | return b | endif
      endfor
      return -1
    endfunction
  else
    " Last resort: synchronous shell.
    function! s:term(cmd) abort
      let parts = map(copy(a:cmd), 'shellescape(v:val)')
      execute 'silent !' . join(parts, ' ')
      call s:open()
      call s:restore()
      redraw!
    endfunction
  endif
endif

" Open files selected by the external picker.
function! s:open(...) abort
  let s:names = []
  if !exists('s:temp') || type(s:temp) != type('') || empty(s:temp) || !filereadable(s:temp)
    redraw!
    return
  endif
  let s:names = readfile(s:temp)
  call delete(s:temp)
  if empty(s:names)
    redraw!
    return
  endif
  execute 'edit' fnameescape(s:names[0])
  for name in s:names[1:]
    execute 'argadd' fnameescape(name)
  endfor
  redraw!
endfunction

if get(g:, 'filepicker_hijack_netrw', 1)
  if !exists('g:loaded_netrw')
    let g:loaded_netrw = 1
    let g:loaded_netrwPlugin = 1
  endif

  let s:_fp_hijacking = 0

  function! s:IsDirBuf(buf) abort
    if !empty(getbufvar(a:buf, '&buftype')) | return 0 | endif
    let name = bufname(a:buf)
    if empty(name) | return 0 | endif
    if name =~# '\v^%(term|man|help|quickfix|fzf|git)[:/]|^\w+://' | return 0 | endif
    return isdirectory(fnamemodify(name, ':p'))
  endfunction

  function! s:OpenDirWithPicker(dir, from_bufnr) abort
    if s:_fp_hijacking | return | endif
    let s:_fp_hijacking = 1
    try
      let dir = fnamemodify(a:dir, ':p')
      noautocmd execute 'silent FilePicker' fnameescape(dir)
      if a:from_bufnr > 0 && bufexists(a:from_bufnr)
        silent! execute 'bwipeout!' a:from_bufnr
      endif
    finally
      let s:_fp_hijacking = 0
    endtry
  endfunction

  function! s:OnVimEnter() abort
    if argc() == 0 | return | endif
    for i in range(argc())
      let p = argv(i)
      if isdirectory(p)
        call s:OpenDirWithPicker(p, bufnr('%'))
        break
      endif
    endfor
  endfunction

  function! s:OnBufEnter() abort
    if s:_fp_hijacking | return | endif
    let bnr = bufnr('%')
    if getbufvar(bnr, 'filepicker_hijacked', 0)
      return
    endif
    if s:IsDirBuf(bnr)
      call setbufvar(bnr, 'filepicker_hijacked', 1)
      call s:OpenDirWithPicker(expand('%:p'), bnr)
    endif
  endfunction

  function! s:OnFileTypeNetrw() abort
    if s:_fp_hijacking
      return
    endif
    let dir = get(b:, 'netrw_curdir', expand('%:p'))
    if isdirectory(dir)
      call s:OpenDirWithPicker(dir, bufnr('%'))
    endif
  endfunction

  augroup FilePickerHijack
    autocmd!
    autocmd VimEnter * call s:OnVimEnter()
    autocmd BufEnter * nested call s:OnBufEnter()
    autocmd FileType netrw call s:OnFileTypeNetrw()
  augroup END
endif
