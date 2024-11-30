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

let s:temp = tempname()
if executable('lf')
  command! -nargs=? -bar -complete=dir FilePicker call FilePicker('lf', '-selection-path', s:temp, <q-args>)
elseif executable('ranger')
  " The option --choosefiles was added in ranger 1.5.1.
  " Use --choosefile with ranger 1.4.2 through 1.5.0 instead.
  command! -nargs=? -bar -complete=dir FilePicker call FilePicker('ranger', '--choosefiles='..s:temp, '--selectfile', <q-args>)
elseif executable('yazi')
  command! -nargs=? -bar -complete=dir FilePicker call FilePicker('yazi', '--chooser-file='..s:temp, <q-args>)
elseif executable('nnn')
  command! -nargs=? -bar -complete=dir FilePicker call FilePicker('nnn', '-p', s:temp, <q-args>)
endif

if exists(':FilePicker') == 2
  function! FilePicker(...)
    let path = a:000[-1]
    if empty(path)
      let path = expand('%')
      if filereadable(path)
        let uses_term = has('nvim') || has('gui_running')
        if !uses_term | let path = shellescape(path,1) | endif
      else
        let path = '.'
      endif
    endif
    let cmd = a:000[:-2] + [path]
    call s:term(cmd)
  endfunction

  if exists('g:vscode')
    let s:code = executable('code') ? 'code' : 'codium'
    if has('unix')
      let s:code_cmd = '('..s:code..' --reuse-window "$(head -n 1 "'..s:temp..'")")'
    elseif has('win32')
      let s:code_cmd = '$filePath = Get-Content -Path "'..s:temp..'" | Select-Object -First 1; '..s:code..' --reuse-window "$filePath"'
    endif
    if exists('s:code_cmd')
    function! s:term(cmd) abort
	call VSCodeNotify('workbench.action.terminal.toggleTerminal')
        call VSCodeNotify('workbench.action.terminal.sendSequence', {'text': join(a:cmd) .. ' && ' .. s:code_cmd .."\n"})
    endfunction
    else
      function! s:term(cmd) abort
        echomsg 'VSCode/Codium only supported on Unix or Win32 operating systems!'
      endfunction
    endif
  elseif has('nvim')
    function! s:term(cmd) abort
      enew
      call termopen(a:cmd, { 'on_exit': function('s:open') })
    endfunction
  else
    if has('gui_running')
      if has('terminal')
        function! s:term(cmd) abort
          call term_start(a:cmd, {'exit_cb': function('s:term_close'), 'curwin': 1})
        endfunction

        function! s:term_close(job_id, event) abort
          if a:event == 'exit'
            bwipeout!
            call s:open()
          endif
        endfunction
      else
        function! s:term(dummy) abort
          echomsg 'GUI is running but terminal is not supported.'
        endfunction
      endif
    else
      function! s:term(cmd) abort
        exec 'silent !'..join(a:cmd) | call s:open()
      endfunction
    endif
  endif

  if !exists('g:vscode')
  function! s:open(...)
    if !filereadable(s:temp)
      " if &buftype ==# 'terminal'
      "   bwipeout!
      " endif
      redraw!
      " Nothing to read.
      return
    endif
    let names = readfile(s:temp)
    if empty(names)
      redraw!
      " Nothing to open.
      return
    endif
    " Edit the first item.
    exec 'edit' fnameescape(names[0])
    " Add any remaning items to the arg list/buffer list.
    for name in names[1:]
      exec 'argadd' fnameescape(name)
    endfor
    redraw!
  endfunction
  endif
endif

if exists("g:no_plugin_maps") || exists("g:no_filepicker_maps") | finish | endif

if exists(':FilePicker') == 2
  nnoremap <silent> <plug>(FilePicker) :<c-u>FilePicker<CR>
else
  nnoremap <silent> <plug>(FilePicker) :<c-u>call <sid>Opendir('edit')<CR>
  function! s:Opendir(cmd) abort
    " fix for - to select the current file,
    " see https://github.com/tpope/vim-vinegar/issues/136
    let save_dir = chdir(expand('%:p:h'))

    if expand('%') =~# '^$\|^term:[\/][\/]'
      execute a:cmd '.'
    else
      execute a:cmd '%:h'
      let pattern = '^\%(| \)*'.escape(expand('#:t'), '.*[]~\').'[/*|@=]\=\%($\|\s\)'
      call search(pattern, 'wc')
    endif

    if !empty(save_dir)
      call chdir(save_dir)
    endif
  endfunction
endif
if !hasmapto('<plug>(FilePicker)', 'n')
  nnoremap <silent> - <plug>(FilePicker)
endif
