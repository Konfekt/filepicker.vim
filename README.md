# Command

This (Neo)Vim plug-in defines a command `:FilePicker` that launches one of the terminal file millers [Ranger](https://ranger.github.io/), [LF](https://github.com/gokcehan/lf), [Yazi](https://github.com/sxyazi/yazi), or [NNN](https://github.com/jarun/nnn) to preview, select and open files on-the-fly in (Neo)Vim.
If no path is given, then it opens that of the currently open file.

# Mapping

By default a mapping of `:FilePicker` to `-` is provided that falls back to built-in Netrw if none of Ranger/LF/Yazi/NNN is available.
It can be remapped by mapping `<plug>(FilePicker)`, and disabled by defining a variable `g:no_filepicker_maps` (or `g:no_plugin_maps`).

# Requirements

Works in Neovim and (G)Vim. For Gvim, `:terminal` support is needed.

## Installation

To use the `:FilePicker` plugin, you need to have at least one of the supported file managers installed on your system.
You can install the plugin using a plugin manager like `vim-plug`:

```vim
call plug#begin('~/.vim/plugged')
Plug 'Konfekt/filepicker.vim'
call plug#end()
```

After installing the plugin, you can start using `:FilePicker` by simply typing `-` in normal mode, or by executing `:FilePicker` in command mode.

