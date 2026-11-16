let s:_picker_cmd  = ''
let s:_picker_name = ''
let s:_picker_key = []
let s:_supported_pickers = ['yazi', 'lf', 'ranger', 'nnn']

function! s:_picker_allowed(name) abort
  if index(s:_supported_pickers, a:name) < 0 | return 0 | endif

  " Yazi's DA1 query times out in Unix Gvim unless 'guioptions' includes '!'
  " which provides a proper terminal for :! commands (see vim/vim#19835)
  if a:name ==# 'yazi' && has('gui_running') && has('unix') && !has('nvim')
        \ && &guioptions !~# '!'
        \ && !get(g:, 'filepicker_allow_yazi_in_gui', 0)
    return 0
  endif

  return 1
endfunction

function! s:detect_picker() abort
  " Detect again whenever an input changed, e.g. 'guioptions' set in a gvimrc
  " (sourced after plugins) or g:filepicker_prefer changed at runtime.
  let prefer = get(g:, 'filepicker_prefer', '')
  let key = [prefer, has('gui_running'), &guioptions =~# '!',
        \ get(g:, 'filepicker_allow_yazi_in_gui', 0)]
  if key ==# s:_picker_key
    return
  endif
  let s:_picker_key = key
  let s:_picker_cmd  = ''
  let s:_picker_name = ''

  if type(prefer) == v:t_string && !empty(prefer) && executable(prefer)
    let name = fnamemodify(prefer, ':t:r')
    if s:_picker_allowed(name)
      let s:_picker_cmd = prefer
      let s:_picker_name = name
      return
    endif
  endif

  for name in s:_supported_pickers
    if executable(name) && s:_picker_allowed(name)
      let s:_picker_cmd  = name
      let s:_picker_name = name
      return
    endif
  endfor
endfunction

function! filepicker#PickerAvailable() abort
  call s:detect_picker()
  return !empty(s:_picker_cmd)
endfunction

" Fallback without an external picker: open the directory with netrw and put
" the cursor on the current file.
function! s:Opendir(dir) abort
  if !empty(a:dir)
    execute 'edit' fnameescape(a:dir)
  elseif expand('%') =~# '^$\|^term:[\/][\/]'
    edit .
  else
    let name = expand('%:t')
    execute 'edit' fnameescape(expand('%:p:h'))
    if !empty(name)
      call search('^\%(| \)*\V' . escape(name, '\') . '\m[/*|@=]\=\%($\|\s\)', 'wc')
    endif
  endif
endfunction

function! s:_normalize_pwd(dir) abort
  if type(a:dir) != v:t_string || empty(a:dir)
    return ''
  endif
  " Strip one trailing slash/backslash (except for root-like paths).
  let p = a:dir
  if strlen(p) > 1 && p =~# '[/\\]$' && p !~# '^\a:[/\\]$'
    let p = substitute(p, '[/\\]$', '', '')
  endif
  return p
endfunction

function! filepicker#FilePicker(...) abort
  call s:detect_picker()

  let user_arg = a:0 ? a:1 : ''
  if empty(s:_picker_cmd)
    call s:Opendir(user_arg)
    return
  endif

  " Resolve input path, defaulting to the current buffer's path or CWD.
  let user_path = ''
  if type(user_arg) == v:t_string && !empty(user_arg)
    " Expand ~, $VAR, etc. only if the argument is not an existing path as is.
    let user_path = isdirectory(user_arg) || filereadable(user_arg)
          \ ? user_arg : expand(user_arg)
    let user_path = fnamemodify(user_path, ':p')
  endif

  let start_dir = ''
  let select_file = ''

  if !empty(user_path)
    if isdirectory(user_path)
      let start_dir = user_path
    elseif filereadable(user_path)
      let select_file = user_path
      let start_dir = fnamemodify(select_file, ':h')
    endif
  endif

  if empty(start_dir)
    let cur = expand('%:p')
    if filereadable(cur)
      let start_dir = fnamemodify(cur, ':h')
      let select_file = cur
    elseif isdirectory(cur)
      let start_dir = cur
    else
      let start_dir = getcwd()
    endif
  endif

  " Use fresh temp files for each run to avoid stale selections.
  let s:selection_file = tempname()
  let s:cwd_file = tempname()

  let cmd = s:build_cmd(s:_picker_name, start_dir, select_file)

  " Ensure tools that consult $PWD (instead of getcwd()) still start correctly.
  let env = {'PWD': s:_normalize_pwd(start_dir)}
  if s:_picker_name ==# 'lf'
    let env['LF_CD_FILE'] = s:cwd_file
  elseif s:_picker_name ==# 'nnn'
    let env['NNN_TMPFILE'] = s:cwd_file
  endif

  call s:save()
  try
    call s:term(cmd, start_dir, env)
  catch
    call s:back_to_prev()
    call s:cleanup()
    call s:restore()
    echohl ErrorMsg
    echomsg '[filepicker] Failed to start ' . s:_picker_cmd . ': ' . v:exception
    echohl None
  endtry
endfunction

function! s:_extra_args(name) abort
  let args = get(g:, 'filepicker_args', {})
  if type(args) != v:t_dict
    return []
  endif
  let val = get(args, a:name, get(args, '*', []))
  if type(val) == v:t_list
    return copy(val)
  elseif type(val) == v:t_string
    return split(val)
  endif
  return []
endfunction

" Build the external picker command list for termopen/term_start or shell fallback.
function! s:build_cmd(picker_name, start_dir, select_file) abort
  if a:picker_name ==# 'yazi'
    let cmd = [s:_picker_cmd, '--chooser-file', s:selection_file, '--cwd-file', s:cwd_file]
  elseif a:picker_name ==# 'lf'
    let cmd = [s:_picker_cmd, '-selection-path', s:selection_file]
  elseif a:picker_name ==# 'ranger'
    let cmd = [s:_picker_cmd, '--choosefiles=' . s:selection_file, '--choosedir=' . s:cwd_file]
  elseif a:picker_name ==# 'nnn'
    let cmd = [s:_picker_cmd, '-p', s:selection_file]
  endif

  " Add user extra args after built-in flags but before positional path.
  let cmd += s:_extra_args(a:picker_name)

  " Prefer selecting a file when provided; otherwise pass the start directory explicitly.
  call add(cmd, empty(a:select_file) ? a:start_dir : a:select_file)
  return cmd
endfunction

" Replace {buf} by a scratch buffer in every window showing it, so that wiping
" it doesn't close the window/tabpage.
function! s:_keep_windows_open(buf) abort
  for id in win_findbuf(a:buf)
    if win_gotoid(id)
      keepalt enew
      setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
    endif
  endfor
endfunction

let s:_fp_prev_bufnr = -1

" Save context and prevent 'wipe' for the previous buffer while the picker runs.
function! s:save() abort
  let s:_fp_prev_bufnr      = bufnr('%')
  let s:_fp_prev_bufhidden  = getbufvar(s:_fp_prev_bufnr, '&bufhidden')
  let s:_fp_prev_hidden_opt = &hidden

  set hidden

  if getbufvar(s:_fp_prev_bufnr, '&buftype') ==# ''
        \ && s:_fp_prev_bufhidden ==# 'wipe'
    call setbufvar(s:_fp_prev_bufnr, '&bufhidden', 'hide')
  endif
endfunction

" Show the previous buffer again in the current window, if it still exists.
function! s:back_to_prev() abort
  let prev_buf = s:_fp_prev_bufnr
  if prev_buf > 0 && bufexists(prev_buf) && bufnr('%') != prev_buf
    execute 'keepalt buffer' prev_buf
  endif
endfunction

" Restore the original options.
function! s:restore() abort
  let prev_buf = s:_fp_prev_bufnr
  if exists('s:_fp_prev_bufhidden') && prev_buf > 0 && bufexists(prev_buf)
    call setbufvar(prev_buf, '&bufhidden', s:_fp_prev_bufhidden)
  endif
  if exists('s:_fp_prev_hidden_opt') && !s:_fp_prev_hidden_opt
    set nohidden
  endif
endfunction

" Delete this run's temp files.
function! s:cleanup() abort
  for f in [get(s:, 'selection_file', ''), get(s:, 'cwd_file', '')]
    if !empty(f)
      call delete(f)
    endif
  endfor
endfunction

" After the picker exited: wipe its terminal buffer {term_buf} (if any), show
" the previous buffer again, open the selection and restore options.
function! s:finish(term_buf) abort
  try
    if a:term_buf > 0 && bufexists(a:term_buf)
      let save_ei = &eventignore
      set eventignore+=BufEnter
      try
        call s:_keep_windows_open(a:term_buf)
        " The buffer may already be gone if it had 'bufhidden' set to wipe.
        if bufexists(a:term_buf)
          execute 'bwipeout!' a:term_buf
        endif
      finally
        let &eventignore = save_ei
      endtry
    endif
    call s:back_to_prev()
    call s:open()
  finally
    call s:cleanup()
    call s:restore()
    redraw!
  endtry
endfunction

if has('nvim')
  " Neovim: run picker in a dedicated terminal buffer, wipe it on exit, then open files and restore.
  function! s:term(cmd, cwd, env) abort
    enew
    let term_buf = bufnr('%')
    setlocal nobuflisted bufhidden=wipe
    let opts = {'on_exit': function('s:_nvim_term_on_exit', [term_buf]),
          \ 'cwd': a:cwd, 'env': a:env}
    call termopen(a:cmd, opts)
    startinsert
  endfunction

  function! s:_nvim_term_on_exit(term_buf, job_id, code, event) abort
    " Slight defer to flush terminal I/O.
    call timer_start(1, {-> s:finish(a:term_buf)})
  endfunction
elseif has('terminal')
  function! s:term(cmd, cwd, env) abort
    let opts = {'curwin': 1, 'exit_cb': function('s:_vim_term_on_exit'),
          \ 'cwd': a:cwd, 'env': a:env}
    try
      call term_start(a:cmd, opts)
    catch /^Vim\%((\a\+)\)\=:E475/
      " Older Vim without the 'env' option: pass the variables via env(1).
      if !executable('env')
        throw v:exception
      endif
      unlet opts.env
      call term_start(['env'] + map(sort(keys(a:env)), 'v:val . "=" . a:env[v:val]')
            \ + a:cmd, opts)
    endtry
    setlocal nobuflisted
    startinsert
  endfunction

  function! s:_vim_term_on_exit(job, status) abort
    let term_buf = -1
    for b in term_list()
      if term_getjob(b) is a:job
        let term_buf = b
        break
      endif
    endfor
    call s:finish(term_buf)
  endfunction
else
  " Last resort: synchronous shell.
  function! s:term(cmd, cwd, env) abort
    " Escape for :! so that %, # and ! in paths are not expanded by Vim.
    let cmdline = join(map(copy(a:cmd), 'shellescape(v:val, 1)'))
    if executable('env')
      let cmdline = 'env ' . join(map(sort(keys(a:env)),
            \ 'shellescape(v:val . "=" . a:env[v:val], 1)')) . ' ' . cmdline
    endif

    " chdir() keeps the scope (global, tab or window) of the current directory.
    let save_dir = chdir(a:cwd)
    try
      execute 'silent !' . cmdline
    finally
      if !empty(save_dir)
        call chdir(save_dir)
      endif
    endtry
    call s:finish(-1)
  endfunction
endif

function! s:_read_first_line(path) abort
  if !filereadable(a:path)
    return ''
  endif
  let lines = readfile(a:path, '', 1)
  return empty(lines) ? '' : substitute(lines[0], '\r$', '', '')
endfunction

" Open files selected by the external picker, or else cd to its last directory.
function! s:open() abort
  let names = filereadable(s:selection_file) ? readfile(s:selection_file) : []
  call map(names, 'substitute(v:val, "\\r$", "", "")')
  call filter(names, '!empty(v:val)')

  if !empty(names)
    let how = get(g:, 'filepicker_open', 'drop')
    let how = get({'tab': 'tabedit', 'tabdrop': 'tab drop'}, how, how)
    if index(['drop', 'edit', 'split', 'vsplit', 'tabedit', 'tab drop'], how) < 0
      let how = 'drop'
    endif

    execute how fnameescape(names[0])
    for name in names[1:]
      execute 'argadd' fnameescape(name)
    endfor
    return
  endif

  " No selection: try to cd to the picker's last directory on quit.
  let last_dir = s:_read_first_line(s:cwd_file)
  if !empty(last_dir)
    let last_dir = fnamemodify(last_dir, ':p')
    if isdirectory(last_dir)
      execute 'cd' fnameescape(last_dir)
    endif
  endif
endfunction

let s:_fp_hijacking = 0

function! s:IsDirBuf(buf) abort
  if !empty(getbufvar(a:buf, '&buftype'))
    return 0
  endif
  let name = bufname(a:buf)
  if empty(name)
    return 0
  endif
  if name =~# '\v^%(term|man|help|quickfix|fzf|git)[:/]|^\w+://'
    return 0
  endif
  return isdirectory(fnamemodify(name, ':p'))
endfunction

function! s:hijack_ok() abort
  return get(g:, 'filepicker_hijack_netrw', 1) && !s:_fp_hijacking
        \ && filepicker#PickerAvailable()
endfunction

function! s:OpenDirWithPicker(dir, from_bufnr) abort
  let s:_fp_hijacking = 1
  try
    let dir = fnamemodify(a:dir, ':p')
    " Call directly to avoid Ex-escaping issues with fnameescape() + <q-args>.
    noautocmd call filepicker#FilePicker(dir)
    if a:from_bufnr > 0 && bufexists(a:from_bufnr)
      execute 'bwipeout!' a:from_bufnr
    endif
  finally
    let s:_fp_hijacking = 0
  endtry
endfunction

" At startup, the directory buffer is usually hijacked by BufEnter already;
" this covers the cases where BufEnter did not fire (e.g. lazy loading).
function! filepicker#OnVimEnter() abort
  call filepicker#OnBufEnter()
endfunction

function! filepicker#OnBufEnter() abort
  if !s:hijack_ok()
    return
  endif
  let bnr = bufnr('%')
  if getbufvar(bnr, 'filepicker_hijacked', 0)
    return
  endif
  if s:IsDirBuf(bnr)
    call setbufvar(bnr, 'filepicker_hijacked', 1)
    call s:OpenDirWithPicker(expand('%:p'), bnr)
  endif
endfunction

function! filepicker#OnFileTypeNetrw() abort
  if !s:hijack_ok()
    return
  endif
  let dir = get(b:, 'netrw_curdir', expand('%:p'))
  if isdirectory(dir)
    call s:OpenDirWithPicker(dir, bufnr('%'))
  endif
endfunction
