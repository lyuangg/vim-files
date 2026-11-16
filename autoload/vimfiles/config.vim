" vim-files: default configuration

scriptencoding utf-8
let s:defaults = {
      \ 'vim_files_width': 34,
      \ 'vim_files_side': 'left',
      \ 'vim_files_show_hidden': 0,
      \ 'vim_files_show_git': 1,
      \ 'vim_files_git_untracked': 1,
      \ 'vim_files_sort': 'name',
      \ 'vim_files_sort_dirs_first': 1,
      \ 'vim_files_sort_reverse': 0,
      \ 'vim_files_sort_case_sensitive': 0,
      \ 'vim_files_icons': 1,
      \ 'vim_files_cursorline': 1,
      \ 'vim_files_indent': '  ',
      \ 'vim_files_dir_arrows': ['▸', '▾'],
      \ 'vim_files_ignore': [],
      \ 'vim_files_preview': 1,
      \ 'vim_files_auto_preview': 0,
      \ 'vim_files_preview_fill': 1,
      \ 'vim_files_preview_delay': 200,
      \ 'vim_files_preview_width': 100,
      \ 'vim_files_preview_height': 30,
      \ 'vim_files_preview_max_size': 524288,
      \ 'vim_files_preview_max_lines': 500,
      \ 'vim_files_auto_refresh': 1,
      \ 'vim_files_close_on_open': 0,
      \ 'vim_files_default_mappings': 1,
      \ 'vim_files_map_toggle': '<leader>e',
      \ 'vim_files_map_find': '<leader>E',
      \ 'vim_files_git_symbols': {
      \   'modified': '✗',
      \   'added': '✚',
      \   'deleted': '✖',
      \   'renamed': '➜',
      \   'untracked': '★',
      \   'conflict': '⚠',
      \   'ignored': '◌',
      \ },
      \ }

function! vimfiles#config#init() abort
  for [s:key, s:value] in items(s:defaults)
    if !exists('g:' . s:key)
      let g:{s:key} = s:value
    endif
  endfor

  if type(g:vim_files_side) != v:t_string || index(['left', 'right'], g:vim_files_side) < 0
    let g:vim_files_side = 'left'
  endif
  if type(g:vim_files_width) != v:t_number || g:vim_files_width < 10
    let g:vim_files_width = 34
  endif
  if type(g:vim_files_sort) != v:t_string
        \ || index(['name', 'extension', 'size', 'mtime', 'none'], tolower(g:vim_files_sort)) < 0
    let g:vim_files_sort = 'name'
  else
    let g:vim_files_sort = tolower(g:vim_files_sort)
  endif
  if type(g:vim_files_dir_arrows) != v:t_list || len(g:vim_files_dir_arrows) < 2
    let g:vim_files_dir_arrows = ['▸', '▾']
  endif
  if type(g:vim_files_preview_delay) != v:t_number || g:vim_files_preview_delay < 0
    let g:vim_files_preview_delay = 200
  endif
  if type(g:vim_files_git_symbols) != v:t_dict
    let g:vim_files_git_symbols = {}
  endif
  if type(g:vim_files_ignore) != v:t_list
    let g:vim_files_ignore = []
  endif
endfunction

function! vimfiles#config#symbols() abort
  let l:defaults = {
        \ 'modified': '✗',
        \ 'added': '✚',
        \ 'deleted': '✖',
        \ 'renamed': '➜',
        \ 'untracked': '★',
        \ 'conflict': '⚠',
        \ 'ignored': '◌',
        \ }
  return extend(copy(l:defaults), g:vim_files_git_symbols)
endfunction

" vim: set ts=2 sw=2 sts=2 et fdm=marker:
