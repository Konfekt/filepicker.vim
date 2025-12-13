Launch one of Ranger, LF, Yazi, or NNN to preview, select, and open files in (Neo)Vim via `-` / `:FilePicker`.
If no path is given, then open the path of the current buffer.

- Ranger: https://ranger.github.io/
- LF: https://github.com/gokcehan/lf
- Yazi: https://github.com/sxyazi/yazi
- NNN: https://github.com/jarun/nnn


# Installation

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

- Auto-detect order: `lf`, `ranger`, `yazi`, `nnn`.
- Prefer a specific picker by `let g:filepicker_prefer = 'lf'` or 'ranger', 'yazi', 'nnn', or an absolute path like '/usr/bin/ranger'
- If none is available, falls back to `netrw`.

# Options

- Extra arguments per picker:
    - `let g:filepicker_args = { 'ranger': ['--choosedir=/tmp/dir'], '*': '--chooseflags something' }`
    - Accepts a Dict keyed by picker name or `'*'` for defaults.
    - Values may be a List or a String.

- How to open the first selected file (default: `'drop'`):
    - `let g:filepicker_open = 'drop'` or one of: 'drop', 'edit', 'split', 'vsplit', 'tab', 'tabedit'
    - For `'tab'`/`'tabedit'`, a tab-aware drop is used.

- Hijack Netrw directory buffers (enabled by default):
    - `let g:filepicker_hijack_netrw = 1`
    - When enabled, intercept opening of directories and launch the external picker instead.
    - Applies on startup with directory arguments, when entering a directory buffer, and when netrw would have been opened.
    - Closes the temporary directory buffer after launching the picker.
    - Has effect only when an external picker is available; otherwise `:FilePicker` falls back to `netrw`.
    - Disable by setting `let g:filepicker_hijack_netrw = 0`.


# Last directory

`filepicker.vim` can remember the last directory visited in the picker, even when no files are selected, and then change Vim's working directory to that location.

- Behavior:
    - On exit from the picker without a file selection, the picker can write the last visited directory to a temporary file.
    - `:FilePicker` reads this file and executes `:cd` to that directory.
    - If no last directory was recorded, `:FilePicker` is a no-op.

- Picker support:
    - **ranger**
        - `filepicker.vim` passes `--choosedir=<tempfile>` to ranger.
        - On quit, ranger writes the final directory into that file.
    - **nnn**
        - `filepicker.vim` exports `NNN_TMPFILE=<tempfile>`.
        - nnn writes its last directory to this file on exit.
    - **yazi**
        - `filepicker.vim` reads Yazi's `cwd` from file supplied to (or `--choosedir`).
    - **lf**
        - `filepicker.vim` exports `LF_CD_FILE=<tempfile>` for the duration of the picker run.
        - lf does not write this file by default; configuration in `lfrc` is required (see below).


## lf configuration to switch to last dir in `:FilePicker`

Configure lf so that quitting with a dedicated key writes the current directory to `$LF_CD_FILE`, which `filepicker.vim` sets when launching lf.

Example `~/.config/lf/lfrc` configuration:

```sh
# Write the current directory to $LF_CD_FILE (if set) and then quit this lf instance.
cmd quit-and-cd ${{
    printf '%s' "$PWD" > "${LF_CD_FILE:-$XDG_CACHE_HOME/lf_lastdir}"
    lf -remote "send $id quit"
}}

# Use Q (not q) to trigger the "quit-and-cd" behavior.
map Q quit-and-cd
```

Explanation:

- `LF_CD_FILE` is set by `filepicker.vim` when lf is started via `:FilePicker`.
- The `quit-and-cd` command writes lf's current directory into `$LF_CD_FILE` (or a fallback in `$XDG_CACHE_HOME` for standalone lf usage), then tells the running lf instance to quit via `lf -remote "send $id quit"`.
- `Q` becomes the "quit and record directory" key, whereas `q` remains the regular quit that does not update the last directory.

After that:

- Run `:FilePicker` to enter lf.
- Inside lf, change into the desired directory and press `Q` to exit and `:cd` into the directory recorded by lf.

# Examples

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
- When hijacking is enabled, netrw is prevented from taking over directory buffers; the picker is launched instead.
- Picker CLI flags referenced:
    - LF `-selection-path`: https://github.com/gokcehan/lf#remote-control
    - Ranger `--choosefiles`, `--selectfile`, `--choosedir`: https://github.com/ranger/ranger/wiki/Integration-with-other-programs#file-chooser
    - Yazi `--chooser-file`, `--cwd-file`: https://yazi-rs.github.io/docs/features/#chooser-mode
    - NNN `-p`, `NNN_TMPFILE`: https://github.com/jarun/nnn/wiki/Usage#environment-and-options


# Behavior

- Working directory:
    - Spawn the picker with `cwd` set to the desired start directory.
    - Avoid rely-on-positional-path semantics across pickers.

- File preselection:
    - If the picker supports starting with a specific file selected, pass it explicitly (e.g. `ranger --selectfile FILE`).
    - Otherwise rely on the picker’s `cwd`.

- Editor integration:
    - Neovim: use `termopen()` in a temporary terminal buffer, then wipe it on exit.
    - Vim with `+terminal`: use `term_start()`, then wipe the terminal buffer on exit.
    - Without terminal support: synchronously invoke the picker via `:silent !` and return on exit.

- Selection transport:
    - LF: `lf -selection-path <tempfile>`
    - Ranger: `ranger --choosefiles=<tempfile> [--selectfile <file>] --choosedir=<tempfile>`
    - Yazi: `yazi --chooser-file=<tempfile>`
    - NNN: `nnn -p <tempfile>` plus `NNN_TMPFILE=<tempfile>` for last-directory support.

- Multiple selections:
    - Open the first selection as configured by `g:filepicker_open`.
    - Add the rest to the `arglist` for `:argdo`, `:next`, etc.

- No selection / last directory:
    - When the picker exits without selecting any files, a last directory can still be recorded.
    - `:FilePicker` reads that directory and changes Vim's working directory to it.
    - For lf, configure `quit-and-cd` in `lfrc` so that only a dedicated quit key (e.g. `Q`) records the directory, while the regular quit (`q`) leaves Vim's working directory unchanged.

# Requirements

- Neovim or Vim.
- Preferred: Neovim or Vim with `+terminal` support for in-editor terminal.
- Without `+terminal`, synchronous shell fallback is used.


# Changelog

- Added `g:filepicker_hijack_netrw` to replace netrw directory views with the selected external picker.
- Made `:FilePicker` change from Vim's current working directory to the last directory visited in the picker, when no files were selected.
- Improved startup path detection and file preselection.
- Added `g:filepicker_args` for per-picker and default extra arguments.
- Added `g:filepicker_open` to control how the first selection is opened (`drop`, `edit`, `split`, `vsplit`, `tab`, `tabedit`).
- Enhanced picker detection to support absolute paths via `g:filepicker_prefer`.
- Spawn picker with `cwd` set to the start directory to avoid positional-path differences across pickers.
