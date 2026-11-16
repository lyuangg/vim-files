" vim-files: public API

let s:save_cpo = &cpo
set cpo&vim

function! vimfiles#open(...) abort
  call vimfiles#tree#open(a:0 ? a:1 : '')
endfunction

function! vimfiles#toggle(...) abort
  let l:path = a:0 ? a:1 : ''
  if vimfiles#tree#is_open_here()
    call vimfiles#tree#close()
  else
    call vimfiles#tree#open(l:path)
  endif
endfunction

function! vimfiles#close() abort
  call vimfiles#tree#close()
endfunction

function! vimfiles#find() abort
  call vimfiles#tree#find()
endfunction

function! vimfiles#refresh() abort
  if !vimfiles#tree#is_open()
    call vimfiles#ui#error('vim-files: tree is not open')
    return
  endif
  call vimfiles#tree#refresh({'git': 1})
endfunction

function! vimfiles#toggle_hidden() abort
  if vimfiles#tree#is_open()
    call vimfiles#tree#toggle_hidden()
  else
    let g:vim_files_show_hidden = !g:vim_files_show_hidden
    call vimfiles#ui#info('vim-files: hidden files '
          \ . (g:vim_files_show_hidden ? 'shown' : 'hidden'))
  endif
endfunction

function! vimfiles#toggle_git() abort
  if vimfiles#tree#is_open()
    call vimfiles#tree#toggle_git()
  else
    let g:vim_files_show_git = !g:vim_files_show_git
    call vimfiles#ui#info('vim-files: git status '
          \ . (g:vim_files_show_git ? 'enabled' : 'disabled'))
  endif
endfunction

function! vimfiles#toggle_auto_preview() abort
  if vimfiles#tree#is_open()
    call vimfiles#tree#toggle_auto_preview()
  else
    let g:vim_files_auto_preview = !g:vim_files_auto_preview
    call vimfiles#ui#info('vim-files: auto preview '
          \ . (g:vim_files_auto_preview ? 'enabled' : 'disabled'))
  endif
endfunction

function! vimfiles#preview_current() abort
  if !vimfiles#tree#is_open_here()
    call vimfiles#ui#error('vim-files: tree is not open')
    return
  endif
  let l:node = vimfiles#tree#current_node()
  if empty(l:node)
    call vimfiles#ui#info('vim-files: select a node to preview')
    return
  endif
  call vimfiles#preview#toggle(l:node.path)
endfunction

function! vimfiles#sort(...) abort
  let l:mode = a:0 ? tolower(a:1) : ''
  let l:valid = ['name', 'extension', 'size', 'mtime', 'none']
  if empty(l:mode)
    if vimfiles#tree#is_open()
      let l:mode = vimfiles#tree#sort_mode()
    else
      let l:mode = g:vim_files_sort
    endif
    call vimfiles#ui#info('vim-files: sort is "' . l:mode . '"')
    return
  endif
  if index(l:valid, l:mode) < 0
    call vimfiles#ui#error('vim-files: invalid sort mode: ' . l:mode)
    return
  endif
  if vimfiles#tree#is_open()
    call vimfiles#tree#set_sort(l:mode)
  else
    let g:vim_files_sort = l:mode
  endif
endfunction

function! vimfiles#sort_complete(arglead, cmdline, cursorpos) abort
  let l:modes = ['name', 'extension', 'size', 'mtime', 'none']
  return filter(copy(l:modes), 'stridx(v:val, a:arglead) == 0')
endfunction

function! vimfiles#on_write(path) abort
  if !get(g:, 'vim_files_auto_refresh', 1)
    return
  endif
  if !vimfiles#tree#is_open() || !vimfiles#tree#is_open_here()
    return
  endif
  let l:root = vimfiles#tree#root()
  if empty(l:root) || !vimfiles#fs#is_under(a:path, l:root)
    return
  endif
  call vimfiles#tree#refresh({'git': 1})
endfunction

function! vimfiles#highlight() abort
  highlight default link VimFilesRoot Title
  highlight default link VimFilesDir Directory
  highlight default link VimFilesDirArrow Comment
  highlight default link VimFilesIcon Identifier
  highlight default link VimFilesLink Special

  highlight default VimFilesCurrentFile cterm=bold gui=bold ctermfg=81 guifg=#56b6c2

  highlight default VimFilesGitModified cterm=bold ctermfg=11 gui=bold guifg=#e5c07b
  highlight default VimFilesGitAdded    cterm=bold ctermfg=10 gui=bold guifg=#98c379
  highlight default VimFilesGitDeleted  cterm=bold ctermfg=9  gui=bold guifg=#e06c75
  highlight default VimFilesGitRenamed  cterm=bold ctermfg=14 gui=bold guifg=#56b6c2
  highlight default VimFilesGitUntracked cterm=bold ctermfg=13 gui=bold guifg=#c678dd
  highlight default VimFilesGitConflict cterm=bold ctermfg=9 gui=bold guifg=#e06c75
  highlight default VimFilesGitIgnored  ctermfg=8 guifg=#5c6370
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set ts=2 sw=2 sts=2 et fdm=marker:
