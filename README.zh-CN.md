# vim-files

[English](README.md)

vim-files 是 Vim 的文件树插件。该插件在侧边窗口中显示目录结构，并提供文件操作、文件预览、Git 状态显示、排序以及可选的文件图标。

## 环境要求

- Vim 9.0 或更高版本，需包含 `+popupwin` 特性。
- 可选：[vim-devicons](https://github.com/ryanoasis/vim-devicons) 及 Nerd Font，用于显示文件图标。
- 可选：`$PATH` 中的 Git，用于显示仓库状态。
- 递归复制在 Unix 类系统上通过 `cp -R` 实现；Windows 使用 Vimscript 回退实现。

## 安装

使用 vim-plug：

```vim
Plug 'ryanoasis/vim-devicons'
Plug 'lyuangg/vim-files'
```

使用 Vim 包管理方式：

```sh
git clone https://github.com/lyuangg/vim-files.git \
  ~/.vim/pack/plugins/start/vim-files
git clone https://github.com/ryanoasis/vim-devicons.git \
  ~/.vim/pack/plugins/start/vim-devicons
```

若插件管理器未生成帮助标签，执行 `:helptags doc`。

## 命令

| 命令 | 说明 |
|------|------|
| `:VimFiles [path]` | 在当前工作目录或指定路径打开文件树。若参数为文件路径，则在其父目录中定位该文件。 |
| `:VimFilesToggle [path]` | 切换文件树的显示状态。可选路径仅在打开文件树时使用。 |
| `:VimFilesClose` | 关闭文件树。 |
| `:VimFilesFind` | 在文件树中定位当前缓冲区对应的文件。 |
| `:VimFilesRefresh` | 重新加载文件树及 Git 状态。 |
| `:VimFilesToggleHidden` | 显示或隐藏以 `.` 开头的隐藏文件。 |
| `:VimFilesToggleGit` | 启用或禁用 Git 状态显示。 |
| `:VimFilesPreview` | 切换当前节点的预览。目录以列表形式显示。 |
| `:VimFilesToggleAutoPreview` | 切换自动预览。 |
| `:VimFilesSort [mode]` | 设置排序方式：`name`、`extension`、`size`、`mtime` 或 `none`。 |
| `:VimFilesHelp` | 打开按键帮助窗口。 |

默认全局映射仅在对应按键尚未被映射时安装：

| 按键 | 映射 |
|------|------|
| `<leader>e` | `:VimFilesToggle` |
| `<leader>E` | `:VimFilesFind` |

同时提供以下 `<Plug>` 映射：

```vim
nmap <F2> <Plug>(vim-files-toggle)
nmap <F3> <Plug>(vim-files-find)
```

执行 `let g:vim_files_default_mappings = 0` 可禁用默认映射。

## 文件树按键

| 按键 | 操作 |
|------|------|
| `j`、`k`、方向键 | 移动光标。 |
| `<CR>`、`o`、`<2-LeftMouse>` | 打开选中文件，或展开、折叠选中目录。 |
| `go` | 打开选中文件，并将焦点保留在文件树中。 |
| `l`、`<Right>` | 展开选中目录，或打开选中文件。 |
| `h`、`<Left>` | 折叠选中目录，或将光标移至其父目录。 |
| `t` | 在新标签页中打开选中文件。 |
| `s` | 在垂直分割窗口中打开选中文件。 |
| `i` | 在水平分割窗口中打开选中文件。 |
| `p` | 切换自动预览。 |
| `<C-p>` | 切换选中节点的手动预览。 |
| `a` | 新建文件或目录。名称以 `/` 结尾时创建目录。 |
| `A` | 新建目录。 |
| `r` | 重命名选中节点。 |
| `d` | 经确认后删除选中节点。 |
| `c` | 标记选中节点以供复制。 |
| `P` | 将已标记节点粘贴到选中目录，或选中文件的父目录。 |
| `y` | 打开路径复制菜单。 |
| `Y` | 复制绝对路径。 |
| `H` | 显示或隐藏以 `.` 开头的隐藏文件。预览打开时，向左滚动预览。 |
| `g` | 启用或禁用 Git 状态显示。 |
| `J`、`K` | 向下或向上滚动预览。 |
| `L` | 向右滚动预览。 |
| `I` | 显示文件详细信息。 |
| `S` | 打开排序菜单。 |
| `R`、`<F5>` | 重新加载文件树及 Git 状态。 |
| `f` | 在文件树中定位当前缓冲区。 |
| `C` | 将选中目录设为文件树根目录。 |
| `u` | 将文件树根目录上移一级。 |
| `m` | 打开操作菜单。 |
| `?` | 打开按键帮助窗口。 |
| `q` | 关闭文件树。 |
| `x` | 关闭当前弹窗。 |
| `Esc` | 关闭预览、详情或帮助弹窗。参见下文说明。 |
| `<C-d>`、`<C-u>`、`<C-e>`、`<C-y>`、`<C-f>`、`<C-b>` | 滚动预览。 |

文件树缓冲区使用 `filetype=vim-files`。可在 `ftplugin/vim-files.vim` 中定义额外的缓冲区本地映射。

## 预览

预览以浮动弹窗形式显示，不创建分割窗口，也不将文件加载到编辑缓冲区。弹窗占据文件树旁的区域：文件树位于左侧时占据右侧，位于右侧时占据左侧。将 `g:vim_files_preview_fill` 设为 `0` 可使用固定尺寸的浮动弹窗。

自动预览默认关闭。按 `p` 启用；启用后，使用 `j`、`k` 移动光标时将显示文件预览。再次按 `p` 将禁用自动预览并关闭预览。通过 `<C-p>`、`m` 菜单或 `:VimFilesPreview` 可切换手动预览。

光标位于目录上时，弹窗显示该目录的列表。二进制文件、不可读文件以及超过大小限制的文件以简短占位文本显示。

预览打开时：

| 按键 | 操作 |
|------|------|
| `J`、`K` | 向下或向上滚动一行。 |
| `H`、`L` | 向左或向右滚动一列。 |
| `<C-d>`、`<C-u>` | 向下或向上滚动十行。 |
| `<C-e>`、`<C-y>` | 向下或向上滚动一行。 |
| `<C-f>`、`<C-b>` | 向下或向上滚动二十行。 |
| `x` | 立即关闭预览。 |
| `Esc` | 关闭预览。响应可能受 Vim 对转义序列的超时处理影响而延迟。 |

如需使 `Esc` 立即生效，可设置：

```vim
set ttimeout ttimeoutlen=100
```

快速移动光标时，预览更新由 `g:vim_files_preview_delay` 合并延迟。将该值设为 `0` 可在每次光标移动时更新预览。

## 文件操作

- 新建文件或目录的名称相对于选中目录，或相对于选中文件的父目录。支持绝对路径。
- 名称以 `/` 结尾时创建目录。`A` 始终创建目录。
- 删除操作需要确认，且不允许删除文件树根目录。
- 复制分为两步：按 `c` 标记一个文件或目录，按 `P` 将其粘贴到选中目录。现有名称不会被覆盖；必要时添加 `name copy` 后缀。
- 重命名不会覆盖现有路径。名称中包含 `/` 时，节点将移动到其他目录。
- 复制路径时优先使用系统剪贴板；不可用时使用未命名寄存器。

## Git 状态

Git 状态通过 `git status --porcelain=v1 -z` 获取。目录状态由其内容聚合得到。当前分支显示在文件树状态栏中。按 `R` 或写入缓冲区后，状态将刷新。

| 状态 | 符号 |
|------|------|
| 已修改 | `✗` |
| 已添加或已暂存 | `✚` |
| 已删除 | `✖` |
| 已重命名 | `➜` |
| 未跟踪 | `★` |
| 冲突 | `⚠` |
| 已忽略 | `◌` |

可覆盖上述符号：

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

## 排序

可通过 `:VimFilesSort name|extension|size|mtime|none` 或 `S` 菜单设置排序方式。菜单还可切换目录优先和反向排序。

```vim
let g:vim_files_sort = 'name'
let g:vim_files_sort_dirs_first = 1
let g:vim_files_sort_reverse = 0
let g:vim_files_sort_case_sensitive = 0
```

## 配置

所有配置项均为可选。

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `g:vim_files_width` | `34` | 文件树窗口宽度。 |
| `g:vim_files_side` | `'left'` | 文件树位置：`'left'` 或 `'right'`。 |
| `g:vim_files_show_hidden` | `0` | 以 `.` 开头的隐藏文件的初始可见性。 |
| `g:vim_files_show_git` | `1` | 启用 Git 状态显示。 |
| `g:vim_files_git_untracked` | `1` | 启用时使用 `--untracked-files=all`，否则使用 `normal`。 |
| `g:vim_files_ignore` | `[]` | 始终隐藏的名称或通配符模式。 |
| `g:vim_files_icons` | `1` | 在可用时使用 vim-devicons 图标。 |
| `g:vim_files_indent` | `'  '` | 每一级文件树的缩进字符串。 |
| `g:vim_files_dir_arrows` | `['▸', '▾']` | 目录折叠与展开时使用的箭头。 |
| `g:vim_files_cursorline` | `1` | 高亮文件树中的光标行。 |
| `g:vim_files_preview` | `1` | 启用预览。 |
| `g:vim_files_auto_preview` | `0` | 启用自动预览。 |
| `g:vim_files_preview_fill` | `1` | 铺满文件树旁的区域。 |
| `g:vim_files_preview_delay` | `200` | 预览更新延迟，单位为毫秒。 |
| `g:vim_files_preview_width` | `100` | `fill` 为 `0` 时的最大预览宽度。 |
| `g:vim_files_preview_height` | `30` | `fill` 为 `0` 时的预览高度。 |
| `g:vim_files_preview_max_lines` | `500` | 预览的最大行数。 |
| `g:vim_files_preview_max_size` | `524288` | 预览文件的最大字节数。 |
| `g:vim_files_auto_refresh` | `1` | 在 `BufWritePost` 后刷新。 |
| `g:vim_files_close_on_open` | `0` | 打开文件后关闭文件树。 |
| `g:vim_files_default_mappings` | `1` | 安装默认的 `<leader>` 映射。 |
| `g:vim_files_map_toggle` | `'<leader>e'` | 切换映射；仅在该按键未被占用时安装。 |
| `g:vim_files_map_find` | `'<leader>E'` | 定位映射；仅在该按键未被占用时安装。 |

`g:vim_files_sort*` 与 `g:vim_files_git_symbols` 的说明分别位于“排序”和“Git 状态”章节。

完整文档可通过 `:help vim-files` 查阅。
