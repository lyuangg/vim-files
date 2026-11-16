" vim-files: git status support

let s:save_cpo = &cpo
set cpo&vim

let s:priority = {
      \ 'conflict': 1,
      \ 'modified': 2,
      \ 'added': 3,
      \ 'deleted': 4,
      \ 'renamed': 5,
      \ 'untracked': 6,
      \ 'ignored': 7,
      \ }

function! s:classify(x, y) abort
  let l:x = a:x
  let l:y = a:y
  if l:x ==# '?' || l:y ==# '?'
    return 'untracked'
  endif
  if l:x ==# '!' || l:y ==# '!'
    return 'ignored'
  endif
  if l:x ==# 'U' || l:y ==# 'U'
        \ || (l:x ==# 'A' && l:y ==# 'A')
        \ || (l:x ==# 'D' && l:y ==# 'D')
    return 'conflict'
  endif
  if l:x ==# 'D' || l:y ==# 'D'
    return 'deleted'
  endif
  if l:x ==# 'R' || l:y ==# 'R' || l:x ==# 'C' || l:y ==# 'C'
    return 'renamed'
  endif
  if l:x ==# 'A' || l:y ==# 'A'
    return 'added'
  endif
  return 'modified'
endfunction

function! vimfiles#git#priority(code) abort
  return get(s:priority, a:code, 99)
endfunction

function! vimfiles#git#load(root) abort
  let l:result = {'is_repo': 0, 'branch': '', 'files': {}, 'dirs': {}, 'count': 0}
  if !get(g:, 'vim_files_show_git', 1)
    return l:result
  endif
  if !executable('git')
    return l:result
  endif

  let l:root = vimfiles#fs#strip_slash(vimfiles#fs#normalize(a:root))
  if empty(l:root) || !isdirectory(l:root)
    return l:result
  endif

  let l:untracked = get(g:, 'vim_files_git_untracked', 1)
        \ ? '--untracked-files=all' : '--untracked-files=normal'
  let l:cmd = 'git -C ' . shellescape(l:root)
        \ . ' status --porcelain=v1 -z ' . l:untracked . ' 2>/dev/null'
  let l:out = system(l:cmd)
  if v:shell_error != 0
    return l:result
  endif

  let l:rev = system('git -C ' . shellescape(l:root)
        \ . ' rev-parse --show-prefix --abbrev-ref HEAD 2>/dev/null')
  if v:shell_error == 0
    let l:parts = split(l:rev, '\n', 1)
    let l:prefix = get(l:parts, 0, '')
    let l:result.branch = get(l:parts, 1, '')
  else
    let l:prefix = substitute(system('git -C ' . shellescape(l:root)
          \ . ' rev-parse --show-prefix 2>/dev/null'), '\n\+$', '', '')
    let l:branch = substitute(system('git -C ' . shellescape(l:root)
          \ . ' symbolic-ref --short HEAD 2>/dev/null'), '\n\+$', '', '')
    let l:result.branch = empty(l:branch) ? 'no commits' : l:branch
  endif
  let l:result.is_repo = 1
  if l:result.branch ==# 'HEAD'
    let l:result.branch = 'detached'
  endif

  let l:entries = split(l:out, "\<C-A>")
  let l:i = 0
  while l:i < len(l:entries)
    let l:entry = l:entries[l:i]
    let l:i += 1
    if strlen(l:entry) < 4
      continue
    endif
    let l:x = l:entry[0]
    let l:y = l:entry[1]
    if l:x ==# 'R' || l:x ==# 'C' || l:y ==# 'R' || l:y ==# 'C'
      let l:i += 1
    endif
    let l:rel = strpart(l:entry, 3)
    if empty(l:rel)
      continue
    endif
    if !empty(l:prefix)
      if stridx(l:rel, l:prefix) != 0
        continue
      endif
      let l:rel = strpart(l:rel, strlen(l:prefix))
      if empty(l:rel)
        continue
      endif
    endif
    let l:abs = vimfiles#fs#normalize(vimfiles#fs#join(l:root, l:rel))
    let l:code = s:classify(l:x, l:y)
    let l:result.count += 1

    let l:is_dir_entry = l:rel =~# '/$' || isdirectory(l:abs)
    if l:is_dir_entry
      let l:dir = l:abs
    else
      let l:result.files[l:abs] = l:code
      let l:dir = fnamemodify(l:abs, ':h')
    endif

    let l:guard = 0
    while vimfiles#fs#is_under(l:dir, l:root)
      let l:current = get(l:result.dirs, l:dir, '')
      if empty(l:current) || s:priority[l:code] < s:priority[l:current]
        let l:result.dirs[l:dir] = l:code
      endif
      if l:dir ==# l:root
        break
      endif
      let l:dir = fnamemodify(l:dir, ':h')
      let l:guard += 1
      if l:guard > 512
        break
      endif
    endwhile
  endwhile

  return l:result
endfunction

function! vimfiles#git#symbol(code) abort
  if empty(a:code)
    return ''
  endif
  return get(vimfiles#config#symbols(), a:code, '')
endfunction

function! vimfiles#git#highlight(code) abort
  if empty(a:code)
    return ''
  endif
  return 'VimFilesGit' . toupper(strpart(a:code, 0, 1)) . strpart(a:code, 1)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set ts=2 sw=2 sts=2 et fdm=marker:
