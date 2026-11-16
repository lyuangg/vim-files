" vim-files.vim - a NERDTree-like file tree for Vim
" Maintainer: lyuangg
" License: MIT

if exists('g:loaded_vim_files')
  finish
endif
let g:loaded_vim_files = 1

if v:version < 900 || !has('popupwin')
  echohl WarningMsg
  echomsg 'vim-files requires Vim 9.0 with the +popupwin feature'
  echohl None
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

call vimfiles#config#init()
call vimfiles#highlight()

command! -nargs=? -complete=file VimFiles        call vimfiles#open(<q-args>)
command! -nargs=? -complete=file VimFilesToggle  call vimfiles#toggle(<q-args>)
command! -nargs=0 VimFilesClose                  call vimfiles#close()
command! -nargs=0 VimFilesFind                   call vimfiles#find()
command! -nargs=0 VimFilesRefresh                call vimfiles#refresh()
command! -nargs=0 VimFilesToggleHidden           call vimfiles#toggle_hidden()
command! -nargs=0 VimFilesToggleGit              call vimfiles#toggle_git()
command! -nargs=0 VimFilesPreview                call vimfiles#preview_current()
command! -nargs=0 VimFilesToggleAutoPreview      call vimfiles#toggle_auto_preview()
command! -nargs=? -complete=customlist,vimfiles#sort_complete VimFilesSort call vimfiles#sort(<q-args>)
command! -nargs=0 VimFilesHelp                   call vimfiles#ui#help()

nnoremap <silent> <Plug>(vim-files-toggle) :<C-u>VimFilesToggle<CR>
nnoremap <silent> <Plug>(vim-files-find)   :<C-u>VimFilesFind<CR>
nnoremap <silent> <Plug>(vim-files-close)  :<C-u>VimFilesClose<CR>

if get(g:, 'vim_files_default_mappings', 1)
  let s:key = get(g:, 'vim_files_map_toggle', '<leader>e')
  if !empty(s:key) && empty(maparg(s:key, 'n'))
    execute 'nnoremap <silent> ' . s:key . ' <Plug>(vim-files-toggle)'
  endif
  let s:key = get(g:, 'vim_files_map_find', '<leader>E')
  if !empty(s:key) && empty(maparg(s:key, 'n'))
    execute 'nnoremap <silent> ' . s:key . ' <Plug>(vim-files-find)'
  endif
endif

augroup vim_files_plugin
  autocmd!
  autocmd ColorScheme * call vimfiles#highlight()
  autocmd BufWritePost * call vimfiles#on_write(expand('<afile>:p'))
  autocmd VimResized * call vimfiles#preview#reposition()
  autocmd WinResized * call vimfiles#preview#reposition()
augroup END

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set ts=2 sw=2 sts=2 et fdm=marker:
