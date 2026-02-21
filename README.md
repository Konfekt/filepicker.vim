Launch one of [Yazi](https://yazi-rs.github.io/)
, [LF](https://github.com/gokcehan/lf)
, [Ranger](https://ranger.github.io/)
, or [NNN](https://github.com/jarun/nnn)
to preview, select, and open files in (Neo)Vim via `-` starting at the path of the current buffer and (optionally) replace [Netrw](https://vimhelp.org/pi_netrw.txt.html#netrw) as file browser.

# Installation

Prefer Neovim or Vim with `+terminal` support for in-editor terminal.
Without `+terminal`, synchronous shell fallback is used.
Install with any plugin manager, e.g. vim-plug:

```vim
call plug#begin('~/.vim/plugged')
Plug 'Konfekt/filepicker.vim'
call plug#end()
```

# Command

- `:FilePicker [path]`
    - Start picker in path.
    - If omitted, then start in the current buffer's directory (or CWD if none).
    - Select multiple files; the first is opened, the rest are added to the `arglist` (see `:help arglist`).

# Mapping

- Default normal-mode mapping: `-` → `<Plug>(FilePicker)`.
- Remap by mapping `<Plug>(FilePicker)`.
- Disable default map by setting one of:
    - `let g:no_filepicker_maps = 1`
    - `let g:no_plugin_maps = 1`

- Optionally add corresponding `-` mappings inside the picker itself (lf, ranger, ...), e.g. `map - updir` or `map - cd ..`.


# Picker selection

- Auto-detect order: `yazi`, `lf`, `ranger`, `nnn`.
- Prefer a specific picker by `let g:filepicker_prefer = 'lf'` or 'ranger', 'yazi', 'nnn', or an absolute path like '/usr/bin/ranger'
- If none is available, falls back to `netrw`.

# Options

- Hijack Netrw directory buffers (enabled by default):
    - `let g:filepicker_hijack_netrw = 1`
    - When enabled, intercept opening of directories and launch the external picker instead.
    - Applies on startup with directory arguments, when entering a directory buffer, and when netrw would have been opened.
    - Closes the temporary directory buffer after launching the picker.
    - Has effect only when an external picker is available; otherwise `:FilePicker` falls back to `netrw`.
    - Disable by setting `let g:filepicker_hijack_netrw = 0`.

- How to open the first selected file (default: `'drop'`):
    - `let g:filepicker_open = 'drop'` or one of: 'drop', 'edit', 'split', 'vsplit', 'tab', 'tabedit'
    - For `'tab'`/`'tabedit'`, a tab-aware drop is used.

- Extra arguments per picker:
    - `let g:filepicker_args = { 'ranger': ['--choosedir=/tmp/dir'], '*': '--chooseflags something' }`
    - Accepts a Dict keyed by picker name or `'*'` for defaults.
    - Values may be a List or a String.

# Last directory

`filepicker.vim` can remember the last directory visited in the picker, even when no files are selected, and then change Vim's working directory to that location.

- **yazi**
    - `filepicker.vim` reads Yazi's `cwd` from file supplied to (or `--choosedir`).
- **lf**
    - `filepicker.vim` exports `LF_CD_FILE=<tempfile>` for the duration of the picker run.
    - lf does not write this file by default; configuration in `lfrc` is required to change into the desired directory by pressing `Q` to exit:
        ```
        cmd quit-and-cd ${{
            printf '%s' "$PWD" > "${LF_CD_FILE:-$XDG_CACHE_HOME/lf_lastdir}"
            lf -remote "send $id quit"
        }}
        map Q quit-and-cd
        ```
- **ranger**
    - `filepicker.vim` passes `--choosedir=<tempfile>` to ranger.
    - On quit, ranger writes the final directory into that file.
- **nnn**
    - `filepicker.vim` exports `NNN_TMPFILE=<tempfile>`.
    - nnn writes its last directory to this file on exit.


# Example Configuration

```vim
" Prefer LF if installed; otherwise auto-detect
let g:filepicker_prefer = 'lf'

" Or prefer a full path
let g:filepicker_prefer = '/usr/bin/ranger'

" Pass extra flags to a specific picker and defaults to all pickers
let g:filepicker_args = {
      \ 'ranger': ['--choosedir=/tmp/dir'],
      \ '*': '--chooseflags something'
      \ }

" Open the first selection in a vertical split
let g:filepicker_open = 'vsplit'

" Disable hijacking to keep netrw directory buffers
let g:filepicker_hijack_netrw = 0

" Custom mapping to start the picker
nnoremap <silent> <leader>- <Plug>(FilePicker)

" Start picker in a specific path
" :FilePicker ~/projects
```


# Notes

- On multiple selections, open the first selection and add the rest to the arglist (for :argdo, :next, etc.).
- Picker CLI flags referenced:
    - LF `-selection-path`: https://github.com/gokcehan/lf#remote-control
    - Ranger `--choosefiles`, `--selectfile`, `--choosedir`: https://github.com/ranger/ranger/wiki/Integration-with-other-programs#file-chooser
    - Yazi `--chooser-file`, `--cwd-file`: https://yazi-rs.github.io/docs/features/#chooser-mode
    - NNN `-p`, `NNN_TMPFILE`: https://github.com/jarun/nnn/wiki/Usage#environment-and-options

