" Smoke tests for filepicker.vim with a fake picker (test/bin/lf).
" Run via test/run.sh, which starts Vim or Neovim with this script.

let s:root = fnamemodify(expand('<sfile>:p'), ':h:h')
let s:out = $FILEPICKER_TEST_OUT
let s:errors = []
let s:tmp = fnamemodify(tempname(), ':p:h') . '/fp test %dir'
call mkdir(s:tmp . '/sub', 'p')
let s:a = s:tmp . '/a #1.txt'
let s:b = s:tmp . '/b.txt'
let s:c = s:tmp . '/c.txt'
for s:f in [s:a, s:b, s:c]
  call writefile([fnamemodify(s:f, ':t')], s:f)
endfor
let $FAKE_PICK_FILE = s:tmp . '/pick'
let $FAKE_LOG = s:tmp . '/log'

execute 'set runtimepath^=' . fnameescape(s:root)
" A user mapping of - must survive loading the plugin.
nnoremap - :let g:user_dash = 1<CR>
runtime plugin/filepicker.vim

function! s:check(cond, msg) abort
  if !a:cond
    call add(s:errors, a:msg)
  endif
endfunction

function! s:terminals() abort
  return filter(range(1, bufnr('$')),
        \ 'bufexists(v:val) && getbufvar(v:val, "&buftype") ==# "terminal"')
endfunction

function! s:pick(files, ...) abort
  call writefile(a:files, $FAKE_PICK_FILE)
  let $FAKE_CD = a:0 ? a:1 : ''
  FilePicker
  let n = 0
  while n < 250 && !empty(s:terminals())
    sleep 20m
    let n += 1
  endwhile
  sleep 100m
endfunction

function! s:reset() abort
  silent! only!
  silent! tabonly!
  execute 'edit' fnameescape(s:b)
  silent! %argdelete
  unlet! g:filepicker_open
endfunction

function! s:listed_names() abort
  return map(filter(range(1, bufnr('$')), 'buflisted(v:val)'),
        \ 'fnamemodify(bufname(v:val), ":p")')
endfunction

" Picker detection and mapping.
call s:check(filepicker#PickerAvailable(), 'fake lf not detected')
call s:check(maparg('-', 'n') =~# 'user_dash', 'user mapping of - was overridden')

" Single selection opens the file; the picker starts at the current file.
call s:reset()
call delete($FAKE_LOG)
call s:pick([s:a])
call s:check(expand('%:p') ==# s:a, 'single: expected a, got ' . expand('%:p'))
call s:check(empty(s:terminals()), 'single: terminal buffer left behind')
call s:check(readfile($FAKE_LOG) ==# [s:b], 'single: picker args ' . string(readfile($FAKE_LOG)))
call s:check(winnr('$') == 1, 'single: expected one window')
call s:check(bufname('#') !=# '' && fnamemodify(bufname('#'), ':p') ==# s:b,
      \ 'single: alternate file should be b, got ' . bufname('#'))

" Multiple selections: first is opened, the rest go to the arglist.
call s:reset()
call s:pick([s:a, s:c])
call s:check(expand('%:p') ==# s:a, 'multi: expected a, got ' . expand('%:p'))
call s:check(index(map(argv(), 'fnamemodify(v:val, ":p")'), s:c) >= 0,
      \ 'multi: c not in arglist ' . string(argv()))

" Split: the original window keeps the previous buffer.
call s:reset()
let g:filepicker_open = 'split'
call s:pick([s:a])
call s:check(winnr('$') == 2, 'split: expected two windows, got ' . winnr('$'))
call s:check(expand('%:p') ==# s:a, 'split: expected a, got ' . expand('%:p'))
call s:check(fnamemodify(bufname(winbufnr(2)), ':p') ==# s:b,
      \ 'split: other window shows ' . string(bufname(winbufnr(2))))

" Tab: the original tab keeps the previous buffer.
call s:reset()
let g:filepicker_open = 'tab'
call s:pick([s:a])
call s:check(tabpagenr('$') == 2, 'tab: expected two tabs')
call s:check(fnamemodify(bufname(tabpagebuflist(1)[0]), ':p') ==# s:b,
      \ 'tab: first tab shows ' . string(bufname(tabpagebuflist(1)[0])))

" No selection: return to the previous buffer and cd to the last directory.
call s:reset()
let s:cwd = getcwd()
call s:pick([], s:tmp . '/sub')
call s:check(expand('%:p') ==# s:b, 'cancel: expected b, got ' . expand('%:p'))
call s:check(getcwd() ==# s:tmp . '/sub', 'cancel: cwd is ' . getcwd())
execute 'cd' fnameescape(s:cwd)

" No stray scratch or terminal buffers stay listed.
call s:check(empty(filter(s:listed_names(), 'v:val !~# "\\.txt$"')),
      \ 'stray listed buffers: ' . string(s:listed_names()))

call writefile(s:errors, s:out)
qall!
