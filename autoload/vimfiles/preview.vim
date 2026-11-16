" vim-files: floating file preview

let s:save_cpo = &cpo
set cpo&vim

let s:buf = -1
let s:update_timer = -1
let s:update_serial = 0
let s:preview = {
      \ 'id': -1,
      \ 'path': '',
      \ 'top': 1,
      \ 'left': 0,
      \ 'width': 0,
      \ 'height': 0,
      \ 'lines': [],
      \ 'geom': {},
      \ }

function! s:ensure_buf() abort
  if s:buf > 0 && bufexists(s:buf)
    return s:buf
  endif
  let s:buf = bufadd('')
  if !bufloaded(s:buf)
    call bufload(s:buf)
  endif
  call setbufvar(s:buf, '&buftype', 'nofile')
  call setbufvar(s:buf, '&bufhidden', 'hide')
  call setbufvar(s:buf, '&swapfile', 0)
  call setbufvar(s:buf, '&buflisted', 0)
  call setbufvar(s:buf, '&undolevels', -1)
  call setbufvar(s:buf, '&modifiable', 1)
  return s:buf
endfunction

function! s:set_lines(lines) abort
  let l:buf = s:ensure_buf()
  call setbufvar(l:buf, '&modifiable', 1)
  let l:old = get(getbufinfo(l:buf), 0, {'linecount': 0}).linecount
  let l:lines = empty(a:lines) ? [''] : a:lines
  try
    call setbufline(l:buf, 1, l:lines)
    if l:old > len(l:lines)
      call deletebufline(l:buf, len(l:lines) + 1, l:old)
    endif
  finally
    call setbufvar(l:buf, '&modified', 0)
    call setbufvar(l:buf, '&modifiable', 0)
  endtry
endfunction

function! s:write_lines(lines) abort
  let l:lines = empty(a:lines) ? [''] : a:lines
  if s:valid()
    silent! call popup_settext(s:preview.id, l:lines)
  else
    call s:set_lines(l:lines)
  endif
endfunction

function! s:valid() abort
  if s:preview.id <= 0 || empty(popup_getpos(s:preview.id))
    return 0
  endif
  if s:buf <= 0 || !bufexists(s:buf)
    return 0
  endif
  return winbufnr(s:preview.id) == s:buf
endfunction

function! s:position() abort
  let l:win = vimfiles#tree#win()
  if l:win <= 0
    return {}
  endif
  let l:infos = getwininfo(l:win)
  if empty(l:infos)
    return {}
  endif
  let l:info = l:infos[0]

  let l:fill = get(g:, 'vim_files_preview_fill', 1)
  let l:maxw = max([20, get(g:, 'vim_files_preview_width', 100)])
  let l:width = 0
  let l:col = 0

  if l:fill
    let l:right_room = &columns - (l:info.wincol + l:info.width)
    if l:right_room >= 24
      let l:col = l:info.wincol + l:info.width
      let l:width = &columns - l:col - 4
    else
      let l:left_room = l:info.wincol - 1
      if l:left_room < 24
        return {}
      endif
      let l:col = 1
      let l:width = l:left_room - 5
    endif
  else
    let l:right_room = &columns - (l:info.wincol + l:info.width) - 4
    if l:right_room >= 25
      let l:width = min([l:maxw, l:right_room])
      let l:col = l:info.wincol + l:info.width + 2
    else
      let l:left_room = l:info.wincol - 4
      if l:left_room < 25
        return {}
      endif
      let l:width = min([l:maxw, l:left_room])
      let l:col = max([1, l:info.wincol - l:width - 2])
    endif
  endif

  if l:width < 20
    return {}
  endif

  let l:height_room = &lines - l:info.winrow + 1
  if l:fill
    let l:height = l:height_room - 3
  else
    let l:height = min([get(g:, 'vim_files_preview_height', 30), l:height_room - 3])
  endif
  if l:height < 5
    return {}
  endif

  return {
        \ 'line': l:info.winrow,
        \ 'col': l:col,
        \ 'width': l:width,
        \ 'height': l:height,
        \ }
endfunction

function! s:title(path, truncated) abort
  let l:root = vimfiles#tree#root()
  let l:rel = empty(l:root) ? a:path : vimfiles#fs#relpath(a:path, l:root)
  if empty(l:rel)
    let l:rel = a:path
  endif
  let l:title = ' ' . l:rel
  if a:truncated
    let l:title .= ' (truncated)'
  endif
  return l:title . ' '
endfunction

function! s:open(title) abort
  let l:pos = s:position()
  if empty(l:pos)
    return 0
  endif
  let l:buf = s:ensure_buf()
  let s:preview.width = l:pos.width
  let s:preview.height = l:pos.height
  let s:preview.top = 1
  let s:preview.geom = copy(l:pos)
  let l:id = popup_create(l:buf, {
        \ 'line': l:pos.line,
        \ 'col': l:pos.col,
        \ 'minwidth': l:pos.width,
        \ 'maxwidth': l:pos.width,
        \ 'minheight': l:pos.height,
        \ 'maxheight': l:pos.height,
        \ 'border': [],
        \ 'padding': [0, 1, 0, 1],
        \ 'scrollbar': 1,
        \ 'wrap': 0,
        \ 'fixed': 1,
        \ 'title': a:title,
        \ 'zindex': 50,
        \ 'filtermode': 'n',
        \ 'filter': function('s:filter'),
        \ })
  let s:preview.id = l:id
  return l:id
endfunction

function! s:filter(id, key) abort
  if a:key ==# 'q' || a:key ==# "\<Esc>" || a:key ==# 'x'
    call vimfiles#preview#close()
    return 1
  elseif a:key ==# "\<C-d>"
    call vimfiles#preview#scroll(10)
    return 1
  elseif a:key ==# "\<C-u>"
    call vimfiles#preview#scroll(-10)
    return 1
  elseif a:key ==# "\<C-e>"
    call vimfiles#preview#scroll(1)
    return 1
  elseif a:key ==# "\<C-y>"
    call vimfiles#preview#scroll(-1)
    return 1
  elseif a:key ==# "\<C-f>"
    call vimfiles#preview#scroll(max([1, s:preview.height - 2]))
    return 1
  elseif a:key ==# "\<C-b>"
    call vimfiles#preview#scroll(-max([1, s:preview.height - 2]))
    return 1
  elseif a:key ==# 'J'
    call vimfiles#preview#scroll(1)
    return 1
  elseif a:key ==# 'K'
    call vimfiles#preview#scroll(-1)
    return 1
  elseif a:key ==# 'H'
    call vimfiles#preview#scroll_h(-1)
    return 1
  elseif a:key ==# 'L'
    call vimfiles#preview#scroll_h(1)
    return 1
  endif
  return 0
endfunction

function! s:slice_line(line, left) abort
  if a:left <= 0
    return a:line
  endif
  let l:tabstop = max([1, getbufvar(s:buf, '&tabstop', 8)])
  let l:out = ''
  let l:col = 0
  for l:i in range(strchars(a:line))
    let l:ch = strcharpart(a:line, l:i, 1)
    if l:ch ==# "\t"
      let l:w = l:tabstop - (l:col % l:tabstop)
    else
      let l:w = max([0, strdisplaywidth(l:ch)])
    endif
    if l:col + l:w <= a:left
    elseif l:col < a:left
      let l:out .= repeat(' ', l:col + l:w - a:left)
    else
      let l:out .= l:ch
    endif
    let l:col += l:w
  endfor
  return l:out
endfunction

function! s:display_lines() abort
  if get(s:preview, 'left', 0) <= 0
    return s:preview.lines
  endif
  let l:out = []
  for l:line in s:preview.lines
    call add(l:out, s:slice_line(l:line, s:preview.left))
  endfor
  return l:out
endfunction

function! s:max_line_width() abort
  let l:max = 0
  for l:line in s:preview.lines
    let l:w = strdisplaywidth(l:line)
    if l:w > l:max
      let l:max = l:w
    endif
  endfor
  return l:max
endfunction

function! s:clamp_left() abort
  let l:max_left = max([0, s:max_line_width() - s:preview.width])
  let s:preview.left = min([l:max_left, max([0, s:preview.left])])
endfunction

function! s:apply_display_lines() abort
  call s:write_lines(s:display_lines())
  if s:valid()
    silent! call popup_setoptions(s:preview.id, {'firstline': s:preview.top})
  endif
endfunction

function! s:relpath(path) abort
  let l:root = vimfiles#tree#root()
  let l:rel = empty(l:root) ? a:path : vimfiles#fs#relpath(a:path, l:root)
  return empty(l:rel) ? a:path : l:rel
endfunction

function! s:dir_title(path, count, truncated) abort
  let l:rel = s:relpath(a:path)
  if l:rel ==# '.'
    let l:rel = fnamemodify(a:path, ':t')
  endif
  if empty(l:rel)
    let l:rel = a:path
  endif
  let l:title = ' ' . l:rel
  if l:title !~# '/$'
    let l:title .= '/'
  endif
  let l:title .= ' (' . a:count . ' entries)'
  if a:truncated
    let l:title .= ' (truncated)'
  endif
  return l:title . ' '
endfunction

function! s:ignored_name(name, show_hidden) abort
  if a:name ==# '.' || a:name ==# '..'
    return 1
  endif
  if a:name[0] ==# '.' && !a:show_hidden
    return 1
  endif
  for l:pat in get(g:, 'vim_files_ignore', [])
    if empty(l:pat)
      continue
    endif
    if a:name ==# l:pat || match(a:name, glob2regpat(l:pat)) >= 0
      return 1
    endif
  endfor
  return 0
endfunction

function! s:update_content(path, lines, title, filetype) abort
  let l:lazy = &lazyredraw
  if !l:lazy
    set lazyredraw
  endif
  try
    let l:old_top = s:preview.top
    if s:valid()
      let l:old_top = get(popup_getpos(s:preview.id), 'firstline', l:old_top)
    endif
    let l:buf = s:ensure_buf()
    if getbufvar(l:buf, '&filetype') !=# a:filetype
      noautocmd call setbufvar(l:buf, '&filetype', a:filetype)
    endif
    if getbufvar(l:buf, '&syntax') !=# a:filetype
      silent! call setbufvar(l:buf, '&syntax', a:filetype)
    endif

    let s:preview.lines = a:lines
    let s:preview.path = a:path
    let s:preview.top = 1
    let s:preview.left = 0
    call s:write_lines(a:lines)

    if s:valid()
      let l:opts = {'title': a:title}
      if l:old_top != 1
        let l:opts.firstline = 1
      endif
      silent! call popup_setoptions(s:preview.id, l:opts)
    else
      call s:open(a:title)
    endif
  finally
    if !l:lazy
      set nolazyredraw
      redraw
    endif
  endtry
endfunction

function! vimfiles#preview#show(path, ...) abort
  let l:force = a:0 ? a:1 : 0
  if !get(g:, 'vim_files_preview', 1)
    return
  endif
  let l:path = vimfiles#fs#normalize(a:path)
  if empty(l:path)
    call vimfiles#preview#close()
    return
  endif
  if isdirectory(l:path)
    call vimfiles#preview#show_dir(l:path, l:force)
    return
  endif
  if !vimfiles#fs#is_regular(l:path)
    if l:force
      call vimfiles#ui#info('vim-files: not a regular file, not previewing')
    endif
    call s:update_content(l:path, ['[not a regular file]'], s:title(l:path, 0), '')
    return
  endif
  if s:valid() && s:preview.path ==# l:path && !l:force
    return
  endif

  let l:size = getfsize(l:path)
  let l:max_size = get(g:, 'vim_files_preview_max_size', 524288)
  if l:size < 0
    if l:force
      call vimfiles#ui#info('vim-files: file not found')
    endif
    call s:update_content(l:path, ['[file not found]'], s:title(l:path, 0), '')
    return
  endif
  if l:size > l:max_size
    if l:force
      call vimfiles#ui#info('vim-files: file is too large to preview')
    endif
    call s:update_content(l:path, ['[file too large to preview]'], s:title(l:path, 0), '')
    return
  endif
  if vimfiles#fs#is_binary(l:path)
    if l:force
      call vimfiles#ui#info('vim-files: binary file, not previewing')
    endif
    call s:update_content(l:path, ['[binary file]'], s:title(l:path, 0), '')
    return
  endif

  let l:max = max([10, get(g:, 'vim_files_preview_max_lines', 500)])
  try
    let l:lines = readfile(l:path, '', l:max + 1)
  catch
    if l:force
      call vimfiles#ui#info('vim-files: could not read file for preview')
    endif
    call s:update_content(l:path, ['[cannot read file]'], s:title(l:path, 0), '')
    return
  endtry
  let l:truncated = len(l:lines) > l:max
  if l:truncated
    let l:lines = l:lines[0 : l:max - 1]
  endif
  if empty(l:lines)
    let l:lines = ['[empty file]']
  endif
  let l:ft = vimfiles#fs#filetype(l:path)

  call s:update_content(l:path, l:lines, s:title(l:path, l:truncated), l:ft)
endfunction

function! vimfiles#preview#show_dir(path, ...) abort
  let l:force = a:0 ? a:1 : 0
  if !get(g:, 'vim_files_preview', 1)
    return
  endif
  let l:path = vimfiles#fs#normalize(a:path)
  if empty(l:path) || !isdirectory(l:path)
    return
  endif

  let l:unreadable = 0
  try
    let l:names = readdir(l:path)
  catch
    let l:names = []
    let l:unreadable = 1
  endtry
  let l:show_hidden = get(get(b:, 'vim_files_state', {}), 'show_hidden',
        \ get(g:, 'vim_files_show_hidden', 0))
  let l:entries = []
  for l:name in l:names
    if s:ignored_name(l:name, l:show_hidden)
      continue
    endif
    let l:entry = l:name
    if isdirectory(vimfiles#fs#join(l:path, l:name))
      let l:entry .= '/'
    endif
    call add(l:entries, l:entry)
  endfor
  call sort(l:entries, 'i')

  let l:total = len(l:entries)
  let l:max = max([10, get(g:, 'vim_files_preview_max_lines', 500)])
  let l:truncated = len(l:entries) > l:max
  if l:truncated
    let l:entries = l:entries[0 : l:max - 1]
  endif
  if empty(l:entries)
    let l:entries = [l:unreadable ? '[cannot read directory]' : '[empty directory]']
  endif

  let l:ft = (s:buf > 0 && bufexists(s:buf)) ? getbufvar(s:buf, '&filetype') : ''
  call s:update_content(l:path, l:entries, s:dir_title(l:path, l:total, l:truncated), l:ft)
endfunction

function! vimfiles#preview#toggle(path) abort
  let l:path = vimfiles#fs#normalize(a:path)
  if s:valid() && s:preview.path ==# l:path
    call vimfiles#preview#close()
  elseif isdirectory(l:path)
    call vimfiles#preview#show_dir(l:path, 1)
  else
    call vimfiles#preview#show(l:path, 1)
  endif
endfunction

function! vimfiles#preview#close() abort
  call s:stop_update_timer()
  if s:valid()
    silent! call popup_close(s:preview.id)
  endif
  let s:preview.id = -1
  let s:preview.path = ''
  let s:preview.top = 1
  let s:preview.left = 0
  let s:preview.lines = []
  let s:preview.geom = {}
endfunction

function! vimfiles#preview#scroll_h(delta) abort
  if !s:valid()
    return
  endif
  let l:before = s:preview.left
  let s:preview.left += a:delta
  call s:clamp_left()
  if s:preview.left != l:before
    call s:apply_display_lines()
  endif
endfunction

function! vimfiles#preview#scroll(delta) abort
  if !s:valid()
    return
  endif
  let s:preview.top = get(popup_getpos(s:preview.id), 'firstline', s:preview.top)
  let l:buf = s:ensure_buf()
  let l:total = get(getbufinfo(l:buf), 0, {'linecount': 1}).linecount
  let l:max_top = max([1, l:total - s:preview.height + 1])
  let s:preview.top = min([l:max_top, max([1, s:preview.top + a:delta])])
  silent! call popup_setoptions(s:preview.id, {'firstline': s:preview.top})
endfunction

function! vimfiles#preview#reposition() abort
  if !s:valid()
    return
  endif
  let l:pos = s:position()
  if empty(l:pos)
    call vimfiles#preview#close()
    return
  endif
  let l:old = get(s:preview, 'geom', {})
  let s:preview.width = l:pos.width
  let s:preview.height = l:pos.height
  let l:left_before = s:preview.left
  call s:clamp_left()
  if s:preview.left != l:left_before
    call s:apply_display_lines()
  endif
  let s:preview.geom = copy(l:pos)
  if empty(l:old) || l:old.line != l:pos.line || l:old.col != l:pos.col
    silent! call popup_move(s:preview.id, {
          \ 'line': l:pos.line,
          \ 'col': l:pos.col,
          \ })
  endif
  if empty(l:old) || l:old.width != l:pos.width || l:old.height != l:pos.height
    silent! call popup_setoptions(s:preview.id, {
          \ 'minwidth': l:pos.width,
          \ 'maxwidth': l:pos.width,
          \ 'minheight': l:pos.height,
          \ 'maxheight': l:pos.height,
          \ })
  endif
endfunction

function! s:stop_update_timer() abort
  if s:update_timer > 0
    call timer_stop(s:update_timer)
    let s:update_timer = -1
  endif
endfunction

function! s:update_current_node() abort
  if !get(b:, 'vim_files_is_tree', 0)
        \ || !vimfiles#tree#is_open_here()
    return
  endif
  if !get(g:, 'vim_files_preview', 1)
    call vimfiles#preview#close()
    return
  endif
  let l:vf = get(b:, 'vim_files_state', {})
  if !get(l:vf, 'auto_preview', 1)
    return
  endif
  let l:node = get(get(l:vf, 'nodes', []), line('.') - 1, {})
  if empty(l:node)
    call vimfiles#preview#close()
    return
  endif
  if l:node.is_dir
    call vimfiles#preview#show_dir(l:node.path)
  else
    call vimfiles#preview#show(l:node.path)
  endif
endfunction

function! s:update_timer_cb(serial, timer) abort
  if a:serial != s:update_serial
    return
  endif
  let s:update_timer = -1
  let l:delay = get(g:, 'vim_files_preview_delay', 200)
  if l:delay > 0 && getchar(1) != 0
    let s:update_timer = timer_start(max([10, l:delay]),
          \ function('s:update_timer_cb', [a:serial]))
    return
  endif
  call s:update_current_node()
endfunction

function! vimfiles#preview#on_cursor_moved() abort
  if !get(b:, 'vim_files_is_tree', 0)
    return
  endif
  if !get(g:, 'vim_files_preview', 1)
    call vimfiles#preview#close()
    return
  endif
  let l:vf = get(b:, 'vim_files_state', {})
  if !get(l:vf, 'auto_preview', 1)
    return
  endif

  let l:delay = get(g:, 'vim_files_preview_delay', 200)
  let s:update_serial += 1
  if l:delay <= 0
    call s:stop_update_timer()
    call s:update_current_node()
    return
  endif
  call s:stop_update_timer()
  let s:update_timer = timer_start(l:delay,
        \ function('s:update_timer_cb', [s:update_serial]))
endfunction

function! vimfiles#preview#is_open() abort
  return s:valid()
endfunction

function! vimfiles#preview#path() abort
  return s:preview.path
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set ts=2 sw=2 sts=2 et fdm=marker:
