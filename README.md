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
- Prefer a specific picker:
    - `let g:filepicker_prefer = 'lf'`  " or 'ranger', 'yazi', 'nnn', or an absolute path like '/usr/bin/ranger'
    - Must be executable.
- If none is available, falls back to `netrw`.


# Options

- Extra arguments per picker:
    - `let g:filepicker_args = { 'ranger': ['--choosedir=/tmp/dir'], '*': '--chooseflags something' }`
    - Accepts a Dict keyed by picker name or `'*'` for defaults.
    - Values may be a List or a String.

- How to open the first selected file (default: `'drop'`):
    - `let g:filepicker_open = 'drop'`  " one of: 'drop', 'edit', 'split', 'vsplit', 'tab', 'tabedit'
    - For `'tab'`/`'tabedit'`, a tab-aware drop is used.

- Hijack Netrw directory buffers (enabled by default):
    - `let g:filepicker_hijack_netrw = 1`
    - When enabled, intercept opening of directories and launch the external picker instead.
    - Applies on startup with directory arguments, when entering a directory buffer, and when netrw would have been opened.
    - Closes the temporary directory buffer after launching the picker.
    - Has effect only when an external picker is available; otherwise `:FilePicker` falls back to `netrw`.
    - Disable by setting `let g:filepicker_hijack_netrw = 0`.


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
    - Ranger: `ranger --choosefiles=<tempfile> [--selectfile <file>]`
    - Yazi: `yazi --chooser-file=<tempfile>`
    - NNN: `nnn -p <tempfile>`

- Multiple selections:
    - Open the first selection as configured by `g:filepicker_open`.
    - Add the rest to the `arglist` for `:argdo`, `:next`, etc.


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

" Custom mapping
nnoremap <silent> <leader>- <Plug>(FilePicker)

" Start picker in a specific path
" :FilePicker ~/projects
```


# Requirements

- Neovim or Vim.
- Preferred: Neovim or Vim with `+terminal` support for in-editor terminal.
- Without `+terminal`, synchronous shell fallback is used.


# Notes

- On multiple selections, open the first selection and add the rest to the arglist (for :argdo, :next, etc.).
- When hijacking is enabled, netrw is prevented from taking over directory buffers; the picker is launched instead.
- Picker CLI flags referenced:
    - LF `-selection-path`: https://github.com/gokcehan/lf#remote-control
    - Ranger `--choosefiles`, `--selectfile`: https://github.com/ranger/ranger/wiki/Integration-with-other-programs#file-chooser
    - Yazi `--chooser-file`: https://yazi-rs.github.io/docs/features/#chooser-mode
    - NNN `-p`: https://github.com/jarun/nnn/wiki/Usage#environment-and-options


# Changelog

- Added `g:filepicker_hijack_netrw` to replace netrw directory views with the selected external picker.
- Improved startup path detection and file preselection.
- Added `g:filepicker_args` for per-picker and default extra arguments.
- Added `g:filepicker_open` to control how the first selection is opened (`drop`, `edit`, `split`, `vsplit`, `tab`, `tabedit`).
- Enhanced picker detection to support absolute paths via `g:filepicker_prefer`.
- Spawn picker with `cwd` set to the start directory to avoid positional-path differences across pickers.
