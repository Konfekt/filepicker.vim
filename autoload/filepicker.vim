let s:_picker_cmd  = ''
let s:_picker_name = ''
let s:_picker_detected = 0

function! s:detect_picker() abort
  if s:_picker_detected
    return
  endif
  let s:_picker_detected = 1

  if exists('g:filepicker_prefer') && type(g:filepicker_prefer) == type('') && executable(g:filepicker_prefer)
    let s:_picker_cmd  = g:filepicker_prefer
    let s:_picker_name = fnamemodify(g:filepicker_prefer, ':t')
  else
    if executable('lf')
      let s:_picker_cmd = 'lf'     | let s:_picker_name = 'lf'
    elseif executable('ranger')
      let s:_picker_cmd = 'ranger' | let s:_picker_name = 'ranger'
    elseif executable('yazi')
      let s:_picker_cmd = 'yazi'   | let s:_picker_name = 'yazi'
    elseif executable('nnn')
      let s:_picker_cmd = 'nnn'    | let s:_picker_name = 'nnn'
    else
      let s:_picker_cmd = ''       | let s:_picker_name = ''
    endif
  endif
endfunction

function! filepicker#PickerAvailable() abort
  call s:detect_picker()
  return !empty(s:_picker_cmd)
endfunction

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

function! s:_normalize_pwd(dir) abort
  if type(a:dir) != type('') || empty(a:dir)
    return ''
  endif
  " Strip one trailing slash/backslash (except for root-like paths).
  let p = a:dir
  if strlen(p) > 1 && p =~# '[/\\]$'
    let p = substitute(p, '[/\\]$', '', '')
  endif
  return p
endfunction

function! filepicker#FilePicker(...) abort
  call s:detect_picker()

  if empty(s:_picker_cmd)
    call s:Opendir(a:0 ? a:1 : '')
    return
  endif

  call s:save()
  " Use a fresh temp file for each run to avoid stale selections.
  let s:selection_file = tempname()
  let s:cwd_file = tempname()

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
    elseif isdirectory(cur)
      let start_dir = cur
    else
      let start_dir = getcwd()
    endif
  endif

  let cmd = s:build_cmd(s:_picker_name, start_dir, select_file)
  if empty(cmd)
    echohl WarningMsg | echom "[filepicker] No compatible picker found." | echohl None
    return
  endif

  " Ensure tools that consult $PWD (instead of getcwd()) still start correctly.
  let env = {'PWD': s:_normalize_pwd(start_dir)}
  if s:_picker_name ==# 'lf'
    let env['LF_CD_FILE'] = s:cwd_file
  elseif s:_picker_name ==# 'nnn'
    let env['NNN_TMPFILE'] = s:cwd_file
  endif

  call s:term(cmd, start_dir, env)
endfunction

function! s:_extra_args(name) abort
  if !exists('g:filepicker_args') | return [] | endif
  if type(g:filepicker_args) != type({}) | return [] | endif
  let val = get(g:filepicker_args, a:name, get(g:filepicker_args, '*', []))
  if type(val) == type([])
    return copy(val)
  elseif type(val) == type('')
    return split(val)
  endif
  return []
endfunction

" Build the external picker command list for termopen/term_start or shell fallback.
function! s:build_cmd(picker_name, start_dir, select_file) abort
  let cmd = []
  let extra = s:_extra_args(a:picker_name)

  if a:picker_name ==# 'lf'
    let cmd = [s:_picker_cmd, '-selection-path', s:selection_file]
  elseif a:picker_name ==# 'ranger'
    let cmd = [s:_picker_cmd, '--choosefiles=' . s:selection_file, '--choosedir=' . s:cwd_file]
    if !empty(a:select_file) && filereadable(a:select_file)
      call add(cmd, '--selectfile')
    endif
  elseif a:picker_name ==# 'yazi'
    " Use space-separated args for compatibility.
    let cmd = [s:_picker_cmd, '--chooser-file', s:selection_file, '--cwd-file', s:cwd_file]
  elseif a:picker_name ==# 'nnn'
    let cmd = [s:_picker_cmd, '-p', s:selection_file]
  endif

  if empty(cmd) | return [] | endif

  " Add user extra args after built-in flags but before positional path.
  if !empty(extra)
    let cmd += extra
  endif

  " Prefer selecting a file when provided; otherwise pass the start directory explicitly.
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

  if s:_fp_prev_bufnr > 0
        \ && bufexists(s:_fp_prev_bufnr)
        \ && getbufvar(s:_fp_prev_bufnr, '&buftype') ==# ''
        \ && s:_fp_prev_bufhidden ==# 'wipe'
    set hidden
    call setbufvar(s:_fp_prev_bufnr, '&bufhidden', 'hide')
  endif
endfunction

let s:names = []
" Restore the previous window/buffer and original options.
function! s:restore() abort
  let prev_buf = get(s:, '_fp_prev_bufnr', -1)

  if prev_buf > 0 && bufexists(prev_buf) && bufnr('%') != prev_buf && empty(s:names)
    execute 'buffer' prev_buf
  endif

  if exists('s:_fp_prev_bufhidden') && prev_buf > 0 && bufexists(prev_buf)
    call setbufvar(prev_buf, '&bufhidden', s:_fp_prev_bufhidden)
  endif

  if exists('s:_fp_prev_hidden_opt') && !s:_fp_prev_hidden_opt
    set nohidden
  endif
endfunction

function! s:_suppress_bufenter_start() abort
  let s:_saved_eventignore = &eventignore
  if &eventignore =~# '\<BufEnter\>'
    return
  endif
  if empty(&eventignore)
    let &eventignore = 'BufEnter'
  else
    let &eventignore = &eventignore . ',BufEnter'
  endif
endfunction

function! s:_suppress_bufenter_end() abort
  if exists('s:_saved_eventignore')
    let &eventignore = s:_saved_eventignore
    unlet s:_saved_eventignore
  endif
endfunction

if has('nvim')
  " Neovim: run picker in a dedicated terminal buffer, wipe it on exit, then open files and restore.
  function! s:term(cmd, cwd, env) abort
    enew
    let term_buf = bufnr('%')
    setlocal nobuflisted
    let opts = {'on_exit': function('s:_nvim_term_on_exit', [term_buf])}
    if !empty(a:cwd) | let opts.cwd = a:cwd | endif
    if type(a:env) == type({}) && !empty(a:env) | let opts.env = a:env | endif
    call termopen(a:cmd, opts)
    startinsert
  endfunction

  function! s:_nvim_term_on_exit(term_buf, job_id, code, event) abort
    " Slight defer to flush terminal I/O.
    call timer_start(1, function('s:_open_and_wipe', [a:term_buf]))
  endfunction

  function! s:_open_and_wipe(term_buf, ...) abort
    call s:_suppress_bufenter_start()
    try
      call s:_keep_windows_open(a:term_buf)
      if bufexists(a:term_buf)
        execute 'bwipeout!' a:term_buf
      endif
    finally
      call s:_suppress_bufenter_end()
    endtry
    call s:open()
    call s:restore()
  endfunction
else
  if has('terminal')
    function! s:_with_env_cmd(cmd, env) abort
      " Validate inputs.
      if type(a:cmd) != type([]) || empty(a:cmd) | return a:cmd | endif
      if type(a:env) != type({}) || empty(a:env) | return a:cmd | endif

      " Prefer POSIX `env` whenever available (including MSYS2/Cygwin/Git for Windows).
      if executable('env')
        let l:env_cmd = ['env']
        for l:k in sort(keys(a:env))
          call add(l:env_cmd, l:k . '=' . a:env[l:k])
        endfor
        return l:env_cmd + a:cmd
      endif

      " Windows fallback: rewrite cmd.exe and PowerShell payloads.
      if has('win32') || has('win64')
        let l:exe = tolower(fnamemodify(a:cmd[0], ':t'))

        if l:exe ==# 'cmd.exe' || l:exe ==# 'cmd'
          return s:_with_env_cmd_cmdexe(a:cmd, a:env)
        endif

        if l:exe ==# 'powershell.exe' || l:exe ==# 'powershell' || l:exe ==# 'pwsh.exe' || l:exe ==# 'pwsh'
          return s:_with_env_cmd_powershell(a:cmd, a:env)
        endif
      endif

      return a:cmd
    endfunction

    function! s:_with_env_cmd_cmdexe(cmd, env) abort
      " Inject `set "K=V"&` before the existing /C or /K command string.
      let l:out = copy(a:cmd)
      let l:lc = map(copy(l:out), 'tolower(v:val)')

      let l:i = index(l:lc, '/c')
      if l:i < 0 | let l:i = index(l:lc, '/k') | endif
      if l:i < 0 || l:i + 1 >= len(l:out) | return a:cmd | endif

      let l:payload = l:out[l:i + 1]
      let l:prefix = ''

      for l:k in sort(keys(a:env))
        let l:v = a:env[l:k]
        let l:v = substitute(l:v, '"', '^"', 'g')
        let l:prefix .= 'set "' . l:k . '=' . l:v . '"&'
      endfor

      let l:out[l:i + 1] = l:prefix . l:payload
      return l:out
    endfunction

    function! s:_with_env_cmd_powershell(cmd, env) abort
      " Inject `$env:K='V';` before the existing -Command (or -c) script string.
      let l:out = copy(a:cmd)
      let l:lc = map(copy(l:out), 'tolower(v:val)')

      let l:i = index(l:lc, '-command')
      if l:i < 0 | let l:i = index(l:lc, '-c') | endif
      if l:i < 0 || l:i + 1 >= len(l:out) | return a:cmd | endif

      let l:script = l:out[l:i + 1]
      let l:prefix = ''

      for l:k in sort(keys(a:env))
        let l:v = a:env[l:k]
        let l:v = substitute(l:v, "'", "''", 'g')
        let l:prefix .= '$env:' . l:k . " = '" . l:v . "'; "
      endfor

      let l:out[l:i + 1] = l:prefix . l:script
      return l:out
    endfunction

    function! s:term(cmd, cwd, env) abort
      let opts = {'curwin': 1, 'exit_cb': function('s:_vim_term_on_exit')}
      if !empty(a:cwd) | let opts.cwd = a:cwd | endif
      if type(a:env) == type({}) && !empty(a:env) | let opts.env = a:env | endif
      try
        let term_buf = term_start(a:cmd, opts)
      catch /^Vim\%((\a\+)\)\=:E475/
        if has_key(opts, 'env')
          unlet opts.env
          let term_buf = term_start(s:_with_env_cmd(a:cmd, a:env), opts)
        else
          throw v:exception
        endif
      endtry
      setlocal nobuflisted
    endfunction

    function! s:_vim_term_on_exit(job, status) abort
      let term_buf = s:term_buf_for_job(a:job)
      call s:_suppress_bufenter_start()
      try
        if term_buf > 0 && bufexists(term_buf)
          call s:_keep_windows_open(term_buf)
          execute 'bwipeout!' term_buf
        endif
      finally
        call s:_suppress_bufenter_end()
      endtry
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
    function! s:term(cmd, cwd, env) abort
      let parts = map(copy(a:cmd), 'shellescape(v:val)')
      let env_parts = []
      if type(a:env) == type({}) && !empty(a:env) && executable('env')
        for [k, v] in items(a:env)
          call add(env_parts, shellescape(k . '=' . v))
        endfor
      endif
      let save_dir = getcwd()
      try
        if !empty(a:cwd)
          call chdir(a:cwd)
        endif
        if !empty(env_parts)
          execute 'silent !env ' . join(env_parts, ' ') . ' ' . join(parts, ' ')
        else
          execute 'silent !' . join(parts, ' ')
        endif
      finally
        if !empty(a:cwd)
          call chdir(save_dir)
        endif
      endtry
      call s:open()
      call s:restore()
      redraw!
    endfunction
  endif
endif

function! s:_read_first_line(path) abort
  if type(a:path) != type('') || empty(a:path) || !filereadable(a:path)
    return ''
  endif
  let lines = readfile(a:path, '', 1)
  if empty(lines)
    return ''
  endif
  return substitute(lines[0], '\r$', '', '')
endfunction

" Open files selected by the external picker.
function! s:open(...) abort
  let s:names = []

  if exists('s:selection_file') && filereadable(s:selection_file)
    let s:names = readfile(s:selection_file)
    call delete(s:selection_file)
  endif

  if !empty(s:names)
    let how = get(g:, 'filepicker_open', 'drop')

    if how ==# 'tab'
      let how = 'tabedit'
    elseif how ==# 'tabdrop'
      let how = 'tab drop'
    endif

    if index(['drop', 'edit', 'split', 'vsplit', 'tabedit', 'tab drop'], how) < 0
      let how = 'drop'
    endif

    execute how fnameescape(s:names[0])

    for name in s:names[1:]
      execute 'argadd' fnameescape(name)
    endfor

    if exists('s:cwd_file') && filereadable(s:cwd_file) | call delete(s:cwd_file) | endif

    redraw!
    return
  endif

  " No selection: try to cd to the picker's last directory on quit.
  let last_dir = ''

  if exists('s:cwd_file') && filereadable(s:cwd_file)
    let last_dir = s:_read_first_line(s:cwd_file)
    call delete(s:cwd_file)
  endif

  if !empty(last_dir)
    let last_dir = fnamemodify(last_dir, ':p')
    if isdirectory(last_dir)
      execute 'cd' fnameescape(last_dir)
    endif
  endif

  redraw!
endfunction

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
    " Call directly to avoid Ex-escaping issues with fnameescape() + <q-args>.
    silent! noautocmd call filepicker#FilePicker(dir)
    if a:from_bufnr > 0 && bufexists(a:from_bufnr)
      silent! execute 'bwipeout!' a:from_bufnr
    endif
  finally
    let s:_fp_hijacking = 0
  endtry
endfunction

function! filepicker#OnVimEnter() abort
  if !get(g:, 'filepicker_hijack_netrw', 1) | return | endif
  if !filepicker#PickerAvailable() | return | endif
  if argc() == 0 | return | endif
  for i in range(argc())
    let p = argv(i)
    if isdirectory(p)
      call s:OpenDirWithPicker(p, bufnr('%'))
      break
    endif
  endfor
endfunction

function! filepicker#OnBufEnter() abort
  if !get(g:, 'filepicker_hijack_netrw', 1) | return | endif
  if !filepicker#PickerAvailable() | return | endif
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

function! filepicker#OnFileTypeNetrw() abort
  if !get(g:, 'filepicker_hijack_netrw', 1) | return | endif
  if !filepicker#PickerAvailable() | return | endif
  if s:_fp_hijacking
    return
  endif
  let dir = get(b:, 'netrw_curdir', expand('%:p'))
  if isdirectory(dir)
    call s:OpenDirWithPicker(dir, bufnr('%'))
  endif
endfunction
