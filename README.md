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

- Accompany with corresponding mappings for `lf`, `ranger`, ... by adding in `lfrc`, `rc.conf` an entry `map - updir` , `map - cd ..`, ...

# Picker selection

- Auto-detect order: lf, ranger, yazi, nnn.
- Prefer a specific picker:
  - `let g:filepicker_prefer = 'lf'  " or 'ranger', 'yazi', 'nnn', or an absolute path`
  - Must be executable.
- If none is available, falls back to `netrw`.


# Options

- Hijack Netrw directory buffers (enabled by default):
  - `let g:filepicker_hijack_netrw = 1`
  - When enabled, intercept opening of directories and launch the external picker instead.
    - Applies on startup with directory arguments, when entering a directory buffer, and when netrw would have been opened.
    - Closes the temporary directory buffer after launching the picker.
  - Has effect only when an external picker is available; otherwise :FilePicker falls back to netrw.
  - Disable by setting `let g:filepicker_hijack_netrw = 0.`

# Behavior

- If no supported picker is available, `:FilePicker` falls back to netrw to open the target directory.
- With an external picker:
  - Neovim: use `termopen()` in a temporary terminal buffer, then wipe it on exit.
  - Vim with +terminal: use `term_start()`, then wipe the terminal buffer on exit.
  - Without terminal support: synchronously invoke the picker via :silent ! and return to Vim on exit.

- Selection transport:
  - LF: `lf -selection-path <tempfile>`
  - Ranger: `ranger --choosefiles=<tempfile> [--selectfile <file>]`
  - Yazi: `yazi --chooser-file=<tempfile>`
  - NNN: `nnn -p <tempfile>`


# Examples

```vim
" Prefer LF if installed; otherwise auto-detect
let g:filepicker_prefer = 'lf'

" Disable hijacking to keep netrw directory buffers
let g:filepicker_hijack_netrw = 0

" Custom mapping
nnoremap <silent> <leader>- <Plug>(FilePicker)

" Start picker in a specific path
" :FilePicker ~/projects
```

# Requirements

- Neovim or Vim.
- Preferred: Neovim or Vim with +terminal support for in-editor terminal.
- Without +terminal, synchronous shell fallback is used.


# Notes

- On multiple selections, open the first selection and add the rest to the arglist (for :argdo, :next, etc.).
- When hijacking is enabled, netrw is prevented from taking over directory buffers; the picker is launched instead.


# Links

- Ranger: https://ranger.github.io/
- LF: https://github.com/gokcehan/lf
- Yazi: https://github.com/sxyazi/yazi
- NNN: https://github.com/jarun/nnn


# Changelog

- Added `g:filepicker_hijack_netrw` to replace netrw directory views with the selected external picker.
- Improved startup path detection and file preselection.
