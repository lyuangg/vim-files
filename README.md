# vim-files

[中文文档](README.zh-CN.md)

vim-files is a file tree plugin for Vim. It displays a directory tree in a side window and provides file operations, preview, Git status, sorting, and optional file icons.

## Requirements

- Vim 9.0 or later with the `+popupwin` feature.
- Optional: [vim-devicons](https://github.com/ryanoasis/vim-devicons) and a Nerd Font for file icons.
- Optional: Git on `$PATH` for repository status.
- A Unix-like system for recursive copy through `cp -R`. Windows uses a Vimscript fallback.

## Installation

With vim-plug:

```vim
Plug 'ryanoasis/vim-devicons'
Plug 'lyuangg/vim-files'
```

With Vim packages:

```sh
git clone https://github.com/lyuangg/vim-files.git \
  ~/.vim/pack/plugins/start/vim-files
git clone https://github.com/ryanoasis/vim-devicons.git \
  ~/.vim/pack/plugins/start/vim-devicons
```

If the plugin manager does not generate help tags, run `:helptags doc`.

## Commands

| Command | Description |
|---------|-------------|
| `:VimFiles [path]` | Open the tree at the current working directory or at the specified path. A file path is revealed in its parent directory. |
| `:VimFilesToggle [path]` | Toggle the tree. The optional path is used when the tree is opened. |
| `:VimFilesClose` | Close the tree. |
| `:VimFilesFind` | Reveal the file of the current buffer in the tree. |
| `:VimFilesRefresh` | Reload the tree and Git status. |
| `:VimFilesToggleHidden` | Show or hide dotfiles. |
| `:VimFilesToggleGit` | Enable or disable Git status. |
| `:VimFilesPreview` | Toggle a manual preview of the selected node. A directory is displayed as a listing. |
| `:VimFilesToggleAutoPreview` | Toggle automatic preview. |
| `:VimFilesSort [mode]` | Set the sort mode: `name`, `extension`, `size`, `mtime`, or `none`. |
| `:VimFilesHelp` | Open the key help popup. |

Default global mappings are installed only when the key is not already mapped:

| Key | Mapping |
|-----|---------|
| `<leader>e` | `:VimFilesToggle` |
| `<leader>E` | `:VimFilesFind` |

The following `<Plug>` mappings are available:

```vim
nmap <F2> <Plug>(vim-files-toggle)
nmap <F3> <Plug>(vim-files-find)
```

Default mappings can be disabled with `let g:vim_files_default_mappings = 0`.

## Tree Mappings

| Key | Action |
|-----|--------|
| `j`, `k`, arrows | Move the cursor. |
| `<CR>`, `o`, `<2-LeftMouse>` | Open the selected file or toggle the selected directory. |
| `go` | Open the selected file and retain focus in the tree. |
| `l`, `<Right>` | Expand the selected directory or open the selected file. |
| `h`, `<Left>` | Collapse the selected directory or move the cursor to its parent. |
| `t` | Open the selected file in a new tab. |
| `s` | Open the selected file in a vertical split. |
| `i` | Open the selected file in a horizontal split. |
| `p` | Toggle automatic preview. |
| `<C-p>` | Toggle a manual preview of the selected node. |
| `a` | Create a file or directory. A trailing `/` creates a directory. |
| `A` | Create a directory. |
| `r` | Rename the selected node. |
| `d` | Delete the selected node after confirmation. |
| `c` | Mark the selected node for copying. |
| `P` | Paste the marked node into the selected directory or the parent directory of the selected file. |
| `y` | Open the path copy menu. |
| `Y` | Copy the absolute path. |
| `H` | Toggle hidden files. When a preview is open, scroll the preview left. |
| `g` | Toggle Git status. |
| `J`, `K` | Scroll the preview down or up. |
| `L` | Scroll the preview right. |
| `I` | Display file details. |
| `S` | Open the sorting menu. |
| `R`, `<F5>` | Reload the tree and Git status. |
| `f` | Reveal the current buffer in the tree. |
| `C` | Set the selected directory as the tree root. |
| `u` | Move the tree root up one level. |
| `m` | Open the action menu. |
| `?` | Open the key help popup. |
| `q` | Close the tree. |
| `x` | Close the current popup. |
| `Esc` | Close the preview, details popup, or help popup. See the note below. |
| `<C-d>`, `<C-u>`, `<C-e>`, `<C-y>`, `<C-f>`, `<C-b>` | Scroll the preview. |

The tree buffer uses `filetype=vim-files`. Additional buffer-local mappings may be defined in `ftplugin/vim-files.vim`.

## Preview

Preview is displayed in a floating popup. It does not create a split and does not load the file into an editing buffer. The popup occupies the area beside the tree: the right side when the tree is on the left, and the left side when the tree is on the right. Set `g:vim_files_preview_fill = 0` to use a bounded popup instead.

Automatic preview is disabled by default. Press `p` to enable it. While automatic preview is enabled, moving the cursor with `j` and `k` previews files. Press `p` again to disable it and close the preview. A manual preview is toggled with `<C-p>`, the `m` menu, or `:VimFilesPreview`.

When the cursor is on a directory, the popup displays a listing of that directory. Binary files, unreadable files, and files exceeding the configured size limit are displayed as a short placeholder.

When a preview is open:

| Key | Action |
|-----|--------|
| `J`, `K` | Scroll down or up one line. |
| `H`, `L` | Scroll left or right one column. |
| `<C-d>`, `<C-u>` | Scroll down or up 10 lines. |
| `<C-e>`, `<C-y>` | Scroll down or up one line. |
| `<C-f>`, `<C-b>` | Scroll down or up 20 lines. |
| `x` | Close the preview immediately. |
| `Esc` | Close the preview. The response may be delayed by Vim's escape-sequence timeout handling. |

For immediate handling of `Esc`, set `ttimeout` and `ttimeoutlen`:

```vim
set ttimeout ttimeoutlen=100
```

Rapid cursor movement is coalesced by `g:vim_files_preview_delay`. Set the value to `0` to update the preview on every cursor movement.

## File Operations

- New file and directory names are relative to the selected directory or to the parent directory of the selected file. Absolute paths are accepted.
- A trailing `/` in a new name creates a directory. `A` always creates a directory.
- Delete requires confirmation and does not permit deletion of the tree root.
- Copy uses two steps: `c` marks one file or directory, and `P` pastes it into the selected directory. Existing names are not overwritten; a `name copy` suffix is added when necessary.
- Rename does not overwrite an existing path. A path containing `/` moves the node to another directory.
- Path copying uses the system clipboard when available and the unnamed register otherwise.

## Git Status

Git status is obtained with `git status --porcelain=v1 -z`. The status of a directory is aggregated from its contents. The current branch is displayed in the tree statusline. The status is refreshed by `R` and after a buffer is written.

| State | Symbol |
|-------|--------|
| Modified | `✗` |
| Added or staged | `✚` |
| Deleted | `✖` |
| Renamed | `➜` |
| Untracked | `★` |
| Conflict | `⚠` |
| Ignored | `◌` |

The symbols can be overridden:

```vim
let g:vim_files_git_symbols = {
      \ 'modified': 'M',
      \ 'added': 'A',
      \ 'deleted': 'D',
      \ 'renamed': 'R',
      \ 'untracked': '?',
      \ 'conflict': '!',
      \ 'ignored': 'I',
      \ }
```

## Sorting

The sort mode is set with `:VimFilesSort name|extension|size|mtime|none` or with the `S` menu. The menu also toggles directories-first and reverse ordering.

```vim
let g:vim_files_sort = 'name'
let g:vim_files_sort_dirs_first = 1
let g:vim_files_sort_reverse = 0
let g:vim_files_sort_case_sensitive = 0
```

## Configuration

All options are optional.

| Option | Default | Description |
|--------|---------|-------------|
| `g:vim_files_width` | `34` | Tree window width. |
| `g:vim_files_side` | `'left'` | Tree position: `'left'` or `'right'`. |
| `g:vim_files_show_hidden` | `0` | Initial visibility of dotfiles. |
| `g:vim_files_show_git` | `1` | Enable Git status. |
| `g:vim_files_git_untracked` | `1` | Use `--untracked-files=all` when enabled, otherwise `normal`. |
| `g:vim_files_ignore` | `[]` | Names or glob patterns that are always hidden. |
| `g:vim_files_icons` | `1` | Use vim-devicons glyphs when available. |
| `g:vim_files_indent` | `'  '` | Indent string for each tree level. |
| `g:vim_files_dir_arrows` | `['▸', '▾']` | Collapsed and expanded directory arrows. |
| `g:vim_files_cursorline` | `1` | Highlight the cursor line in the tree. |
| `g:vim_files_preview` | `1` | Enable preview. |
| `g:vim_files_auto_preview` | `0` | Enable automatic preview. |
| `g:vim_files_preview_fill` | `1` | Fill the area beside the tree. |
| `g:vim_files_preview_delay` | `200` | Preview update delay in milliseconds. |
| `g:vim_files_preview_width` | `100` | Maximum preview width when `fill` is `0`. |
| `g:vim_files_preview_height` | `30` | Preview height when `fill` is `0`. |
| `g:vim_files_preview_max_lines` | `500` | Maximum number of preview lines. |
| `g:vim_files_preview_max_size` | `524288` | Maximum preview file size in bytes. |
| `g:vim_files_auto_refresh` | `1` | Refresh after `BufWritePost`. |
| `g:vim_files_close_on_open` | `0` | Close the tree after opening a file. |
| `g:vim_files_default_mappings` | `1` | Install the default `<leader>` mappings. |
| `g:vim_files_map_toggle` | `'<leader>e'` | Toggle mapping, installed when the key is free. |
| `g:vim_files_map_find` | `'<leader>E'` | Find mapping, installed when the key is free. |

The `g:vim_files_sort*` and `g:vim_files_git_symbols` options are described in the Sorting and Git Status sections.

Full documentation is available with `:help vim-files`.
