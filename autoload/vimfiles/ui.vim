" vim-files: user interaction (menus, prompts, popups)

let s:save_cpo = &cpo
set cpo&vim

let s:complete_dir = ''
let s:details_id = -1
let s:details_buf = -1
let s:help_id = -1
let s:help_buf = -1

function! s:fit_message(msg) abort
  let l:space = exists('v:echospace') ? v:echospace : &columns - 1
  if type(l:space) != v:t_number || l:space < 10
    let l:space = max([10, &columns - 1])
  endif
  if strdisplaywidth(a:msg) <= l:space
    return a:msg
  endif
  let l:limit = max([1, l:space - 3])
  let l:out = ''
  let l:width = 0
  for l:ch in split(a:msg, '\zs')
    let l:w = strdisplaywidth(l:ch)
    if l:width + l:w > l:limit
      break
    endif
    let l:out .= l:ch
    let l:width += l:w
  endfor
  return l:out . '...'
endfunction

function! vimfiles#ui#info(msg) abort
  redraw
  echohl MoreMsg
  echomsg s:fit_message(a:msg)
  echohl None
endfunction

function! vimfiles#ui#error(msg) abort
  redraw
  echohl ErrorMsg
  echomsg a:msg
  echohl None
endfunction

function! vimfiles#ui#action(name) abort
  let l:node = vimfiles#tree#current_node()
  call vimfiles#ui#run(a:name, get(l:node, 'path', ''), get(l:node, 'is_dir', 0))
endfunction

function! vimfiles#ui#run(action, path, is_dir) abort
  try
    call s:dispatch(a:action, a:path, a:is_dir)
  catch /^vim-files: /
    call vimfiles#ui#error(v:exception)
  catch
    call vimfiles#ui#error('vim-files: ' . v:exception)
  endtry
endfunction

function! s:dispatch(action, path, is_dir) abort
  let l:path = a:path
  let l:is_dir = a:is_dir || (!empty(l:path) && isdirectory(l:path))

  if a:action ==# 'open'
    call vimfiles#tree#activate(l:path)
  elseif a:action ==# 'open_keep_focus'
    if empty(l:path)
      return
    endif
    if l:is_dir
      call vimfiles#tree#toggle_dir(l:path)
    else
      call vimfiles#tree#open_file(l:path, 'edit', 1)
    endif
  elseif a:action ==# 'expand_or_open'
    if l:is_dir
      call vimfiles#tree#expand(l:path)
    else
      call vimfiles#tree#activate(l:path)
    endif
  elseif a:action ==# 'collapse_or_parent'
    if l:is_dir && vimfiles#tree#is_expanded(l:path)
      call vimfiles#tree#collapse(l:path)
    else
      call vimfiles#tree#goto_parent(l:path)
    endif
  elseif a:action ==# 'tab' || a:action ==# 'vsplit' || a:action ==# 'split'
    if empty(l:path)
      return
    endif
    if l:is_dir
      call vimfiles#tree#toggle_dir(l:path)
    else
      call vimfiles#tree#open_file(l:path, a:action)
    endif
  elseif a:action ==# 'preview'
    if empty(l:path)
      return
    endif
    call vimfiles#preview#toggle(l:path)
  elseif a:action ==# 'create'
    call s:create(l:path, l:is_dir, 0)
  elseif a:action ==# 'create_dir'
    call s:create(l:path, l:is_dir, 1)
  elseif a:action ==# 'rename'
    call s:rename(l:path)
  elseif a:action ==# 'delete'
    call s:delete(l:path)
  elseif a:action ==# 'copy'
    call s:mark_copy(l:path)
  elseif a:action ==# 'paste'
    call s:paste(l:path, l:is_dir)
  elseif a:action ==# 'copy_menu'
    call s:copy_menu(l:path)
  elseif a:action ==# 'copy_name'
    call s:copy_text(l:path, 'name')
  elseif a:action ==# 'copy_relpath'
    call s:copy_text(l:path, 'relative path')
  elseif a:action ==# 'copy_abspath'
    call s:copy_text(l:path, 'absolute path')
  elseif a:action ==# 'details'
    call s:details_toggle(l:path)
  elseif a:action ==# 'toggle_hidden'
    call vimfiles#tree#toggle_hidden()
  elseif a:action ==# 'toggle_git'
    call vimfiles#tree#toggle_git()
  elseif a:action ==# 'toggle_auto_preview'
    call vimfiles#tree#toggle_auto_preview()
  elseif a:action ==# 'sort_menu'
    call s:sort_menu()
  elseif a:action ==# 'refresh'
    call vimfiles#tree#refresh({'git': 1})
    call vimfiles#ui#info('vim-files: refreshed')
  elseif a:action ==# 'find'
    call vimfiles#find()
  elseif a:action ==# 'up_root'
    call vimfiles#tree#up_root()
  elseif a:action ==# 'change_root'
    if empty(l:path)
      return
    endif
    call vimfiles#tree#set_root(l:is_dir ? l:path : fnamemodify(l:path, ':h'))
  elseif a:action ==# 'close'
    call vimfiles#close()
  elseif a:action ==# 'help'
    call vimfiles#ui#help()
  elseif a:action ==# 'menu'
    call vimfiles#ui#menu()
  endif
endfunction

function! s:base_dir(path, is_dir) abort
  if empty(a:path)
    return vimfiles#tree#root()
  endif
  if a:is_dir
    return a:path
  endif
  return fnamemodify(a:path, ':h')
endfunction

function! s:prompt(label, default, base) abort
  let s:complete_dir = a:base
  try
    return input(a:label, a:default, 'custom,vimfiles#ui#complete')
  finally
    let s:complete_dir = ''
  endtry
endfunction

function! vimfiles#ui#complete(lead, cmdline, cursorpos) abort
  let l:base = get(s:, 'complete_dir', '')
  if empty(l:base)
    return []
  endif
  let l:matches = getcompletion(vimfiles#fs#join(l:base, a:lead), 'file')
  let l:prefix = l:base ==# '/' ? '/' : l:base . '/'
  let l:out = []
  for l:match in l:matches
    let l:rel = l:match
    if stridx(l:rel, l:prefix) == 0
      let l:rel = strpart(l:rel, strlen(l:prefix))
    endif
    call add(l:out, l:rel)
  endfor
  return l:out
endfunction

function! s:create(path, is_dir, force_dir) abort
  let l:base = s:base_dir(a:path, a:is_dir)
  let l:label = a:force_dir
        \ ? 'New directory: '
        \ : 'New file or directory (end with / for a directory): '
  let l:name = s:prompt(l:label, '', l:base)
  if empty(l:name)
    return
  endif
  if a:force_dir && l:name !~# '[/\\]$'
    let l:name .= '/'
  endif
  let l:target = vimfiles#fs#create(l:base, l:name)
  call vimfiles#tree#refresh({'git': 1, 'cursor': l:target, 'expand': 1})
  call vimfiles#ui#info('vim-files: created ' . l:target)
endfunction

function! s:rename(path) abort
  if empty(a:path)
    return
  endif
  let l:root = vimfiles#tree#root()
  if a:path ==# l:root
    call vimfiles#ui#error('vim-files: cannot rename the tree root')
    return
  endif
  let l:base = fnamemodify(a:path, ':h')
  let l:name = s:prompt('Rename to: ', fnamemodify(a:path, ':t'), l:base)
  if empty(l:name)
    return
  endif
  let l:new = vimfiles#fs#rename(a:path, l:name)
  if l:new ==# a:path
    return
  endif
  call vimfiles#tree#apply_renamed(a:path, l:new)
  call vimfiles#tree#refresh({'git': 1, 'cursor': l:new, 'expand': 1})
  call vimfiles#ui#info('vim-files: renamed to ' . l:new)
endfunction

function! s:delete(path) abort
  if empty(a:path)
    return
  endif
  if a:path ==# vimfiles#tree#root()
    call vimfiles#ui#error('vim-files: cannot delete the tree root')
    return
  endif
  let l:kind = isdirectory(a:path) ? 'directory' : 'file'
  let l:choice = confirm('Delete ' . l:kind . " \"" . a:path . "\"?",
        \ "&Yes\n&No", 2)
  if l:choice != 1
    return
  endif
  call vimfiles#fs#delete(a:path)
  call vimfiles#tree#apply_deleted(a:path)
  call vimfiles#tree#refresh({'git': 1, 'cursor': fnamemodify(a:path, ':h')})
  call vimfiles#ui#info('vim-files: deleted ' . a:path)
endfunction

function! s:mark_copy(path) abort
  if empty(a:path)
    return
  endif
  call vimfiles#tree#set_copy(a:path)
  call vimfiles#ui#info('vim-files: marked for copy: ' . fnamemodify(a:path, ':t')
        \ . '  (P to paste)')
endfunction

function! s:paste(path, is_dir) abort
  let l:src = vimfiles#tree#get_copy()
  if empty(l:src)
    call vimfiles#ui#error('vim-files: nothing copied; press c on a file or directory first')
    return
  endif
  if empty(getftype(l:src))
    call vimfiles#tree#set_copy('')
    call vimfiles#ui#error('vim-files: copied node no longer exists: ' . l:src)
    return
  endif
  let l:base = s:base_dir(a:path, a:is_dir)
  let l:dest = vimfiles#fs#copy(l:src, l:base)
  call vimfiles#tree#set_copy('')
  call vimfiles#tree#refresh({'git': 1, 'cursor': l:dest, 'expand': 1})
  call vimfiles#ui#info('vim-files: copied to ' . l:dest)
endfunction

function! s:copy_text(path, kind) abort
  if empty(a:path)
    return
  endif
  if a:kind ==# 'name'
    let l:text = fnamemodify(a:path, ':t')
  elseif a:kind ==# 'relative path'
    let l:text = vimfiles#fs#relpath(a:path, vimfiles#tree#root())
  else
    let l:text = a:path
  endif
  let l:clip = vimfiles#fs#yank(l:text)
  call vimfiles#ui#info('vim-files: copied ' . a:kind . ': ' . l:text
        \ . (l:clip ? '' : '  (unnamed register)'))
endfunction

function! s:shortcut_filter(items, id, key) abort
  if a:key ==# 'x'
    call popup_close(a:id, -1)
    return 1
  endif
  let l:i = 0
  for l:item in a:items
    if get(l:item, 'key', '') ==# a:key
      call popup_close(a:id, l:i + 1)
      return 1
    endif
    let l:i += 1
  endfor
  return popup_filter_menu(a:id, a:key)
endfunction

function! s:menu_cb(items, path, is_dir, id, result) abort
  if a:result < 1 || a:result > len(a:items)
    return
  endif
  call vimfiles#ui#run(a:items[a:result - 1].action, a:path, a:is_dir)
endfunction

function! vimfiles#ui#menu() abort
  let l:node = vimfiles#tree#current_node()
  let l:path = get(l:node, 'path', '')
  let l:is_dir = get(l:node, 'is_dir', 0)

  let l:items = [
        \ {'key': 'o', 'text': 'Open',                    'action': 'open'},
        \ {'key': 'G', 'text': 'Open (stay in tree)',     'action': 'open_keep_focus'},
        \ {'key': 't', 'text': 'Open in new tab',         'action': 'tab'},
        \ {'key': 's', 'text': 'Open in vertical split',  'action': 'vsplit'},
        \ {'key': 'i', 'text': 'Open in horizontal split','action': 'split'},
        \ {'key': 'v', 'text': 'Preview (manual)',        'action': 'preview'},
        \ {'key': 'a', 'text': 'New file...',             'action': 'create'},
        \ {'key': 'A', 'text': 'New directory...',        'action': 'create_dir'},
        \ {'key': 'r', 'text': 'Rename...',               'action': 'rename'},
        \ {'key': 'd', 'text': 'Delete...',               'action': 'delete'},
        \ {'key': 'c', 'text': 'Copy (mark)',             'action': 'copy'},
        \ {'key': 'P', 'text': 'Paste',                   'action': 'paste'},
        \ {'key': 'n', 'text': 'Copy file name',          'action': 'copy_name'},
        \ {'key': 'y', 'text': 'Copy relative path',      'action': 'copy_relpath'},
        \ {'key': 'Y', 'text': 'Copy absolute path',      'action': 'copy_abspath'},
        \ {'key': 'I', 'text': 'File details',            'action': 'details'},
        \ {'key': 'H', 'text': 'Toggle hidden files',     'action': 'toggle_hidden'},
        \ {'key': 'g', 'text': 'Toggle git status',       'action': 'toggle_git'},
        \ {'key': 'p', 'text': 'Toggle auto preview',     'action': 'toggle_auto_preview'},
        \ {'key': 'S', 'text': 'Sort by...',              'action': 'sort_menu'},
        \ {'key': 'R', 'text': 'Refresh tree',            'action': 'refresh'},
        \ {'key': 'f', 'text': 'Find current file',       'action': 'find'},
        \ {'key': 'C', 'text': 'Change root here',        'action': 'change_root'},
        \ {'key': 'u', 'text': 'Go up one level',         'action': 'up_root'},
        \ {'key': 'q', 'text': 'Close tree',              'action': 'close'},
        \ {'key': '?', 'text': 'Keys help',               'action': 'help'},
        \ ]
  let l:lines = []
  for l:item in l:items
    call add(l:lines, printf(' %s  %s', l:item.key, l:item.text))
  endfor
  call popup_menu(l:lines, {
        \ 'title': ' vim-files ',
        \ 'maxheight': max([8, &lines - 4]),
        \ 'filtermode': 'n',
        \ 'callback': function('s:menu_cb', [l:items, l:path, l:is_dir]),
        \ 'filter': function('s:shortcut_filter', [l:items]),
        \ })
endfunction

function! s:sort_cb(items, id, result) abort
  if a:result < 1 || a:result > len(a:items)
    return
  endif
  let l:act = a:items[a:result - 1].action
  if l:act ==# 'dirs_first'
    call vimfiles#tree#toggle_option('dirs_first')
    call vimfiles#ui#info('vim-files: directories first '
          \ . (vimfiles#tree#sort_state().dirs_first ? 'enabled' : 'disabled'))
  elseif l:act ==# 'reverse'
    call vimfiles#tree#toggle_option('reverse')
    call vimfiles#ui#info('vim-files: reverse order '
          \ . (vimfiles#tree#sort_state().reverse ? 'enabled' : 'disabled'))
  else
    call vimfiles#tree#set_sort(l:act)
  endif
endfunction

function! s:sort_menu() abort
  let l:state = vimfiles#tree#sort_state()
  let l:modes = [
        \ {'key': 'n', 'text': 'Name',       'action': 'name',      'value': l:state.mode},
        \ {'key': 'e', 'text': 'Extension',  'action': 'extension', 'value': l:state.mode},
        \ {'key': 's', 'text': 'Size',       'action': 'size',      'value': l:state.mode},
        \ {'key': 'm', 'text': 'Modified',   'action': 'mtime',     'value': l:state.mode},
        \ {'key': 'o', 'text': 'None (filesystem order)', 'action': 'none', 'value': l:state.mode},
        \ {'key': 'd', 'text': 'Directories first', 'action': 'dirs_first',
        \  'value': l:state.dirs_first ? 1 : 0},
        \ {'key': 'v', 'text': 'Reverse order', 'action': 'reverse',
        \  'value': l:state.reverse ? 1 : 0},
        \ ]
  let l:lines = []
  for l:item in l:modes
    if l:item.action ==# 'dirs_first' || l:item.action ==# 'reverse'
      let l:mark = l:item.value ? 'on' : 'off'
    else
      let l:mark = l:item.value ==# l:item.action ? '*' : ' '
    endif
    call add(l:lines, printf(' %s %s  %s', l:mark, l:item.key, l:item.text))
  endfor
  call popup_menu(l:lines, {
        \ 'title': ' Sort by ',
        \ 'maxheight': max([8, &lines - 4]),
        \ 'filtermode': 'n',
        \ 'callback': function('s:sort_cb', [l:modes]),
        \ 'filter': function('s:shortcut_filter', [l:modes]),
        \ })
endfunction

function! s:copy_cb(modes, path, id, result) abort
  if a:result < 1 || a:result > len(a:modes)
    return
  endif
  call vimfiles#ui#run(a:modes[a:result - 1].action, a:path, 0)
endfunction

function! s:copy_menu(path) abort
  if empty(a:path)
    return
  endif
  let l:modes = [
        \ {'key': 'n', 'text': 'File name',     'action': 'copy_name'},
        \ {'key': 'r', 'text': 'Relative path', 'action': 'copy_relpath'},
        \ {'key': 'a', 'text': 'Absolute path', 'action': 'copy_abspath'},
        \ ]
  let l:lines = []
  for l:item in l:modes
    call add(l:lines, printf(' %s  %s', l:item.key, l:item.text))
  endfor
  call popup_menu(l:lines, {
        \ 'title': ' Copy ',
        \ 'maxheight': max([8, &lines - 4]),
        \ 'filtermode': 'n',
        \ 'callback': function('s:copy_cb', [l:modes, a:path]),
        \ 'filter': function('s:shortcut_filter', [l:modes]),
        \ })
endfunction

function! s:close_filter(id, key) abort
  if a:key ==# 'q' || a:key ==# "\<Esc>" || a:key ==# 'x' || a:key ==# "\<CR>"
    call popup_close(a:id)
    return 1
  endif
  return 0
endfunction

function! s:details_valid() abort
  return s:details_id > 0 && !empty(popup_getpos(s:details_id))
        \ && winbufnr(s:details_id) == s:details_buf
endfunction

function! s:help_valid() abort
  return s:help_id > 0 && !empty(popup_getpos(s:help_id))
        \ && winbufnr(s:help_id) == s:help_buf
endfunction

function! s:details_toggle(path) abort
  if s:details_valid()
    call popup_close(s:details_id)
    let s:details_id = -1
    return
  endif
  if empty(a:path)
    return
  endif

  let l:info = vimfiles#fs#info(a:path)
  let l:git = vimfiles#tree#git_code(a:path)
  let l:type = l:info.is_dir ? 'directory' : l:info.type
  if l:info.link
    let l:type = 'symlink'
  endif
  let l:perm = l:info.perm
  if empty(l:perm)
    let l:perm = 'unknown'
  else
    let l:perm = (l:info.link ? 'l' : (l:info.is_dir ? 'd' : '-')) . l:perm
  endif

  let l:lines = [
        \ printf('%-13s %s', 'Path', l:info.path),
        \ printf('%-13s %s', 'Type', l:type),
        \ printf('%-13s %s', 'Size', l:info.is_dir
        \   ? (l:info.entries >= 0 ? l:info.entries . ' entries' : 'unknown')
        \   : vimfiles#fs#format_size(l:info.size)),
        \ printf('%-13s %s', 'Modified', vimfiles#fs#pretty_time(l:info.mtime)),
        \ printf('%-13s %s', 'Permissions', l:perm),
        \ printf('%-13s %s', 'Git', empty(l:git) ? 'clean' : l:git),
        \ ]
  if l:info.is_dir
    call add(l:lines, printf('%-13s %s', 'Entries', l:info.entries >= 0 ? l:info.entries : 'unknown'))
  else
    let l:ft = vimfiles#fs#filetype(a:path)
    if !empty(l:ft)
      call add(l:lines, printf('%-13s %s', 'Filetype', l:ft))
    endif
    if l:info.lines >= 0
      call add(l:lines, printf('%-13s %d%s', 'Lines', l:info.lines,
            \ get(l:info, 'lines_truncated', 0) ? '+' : ''))
    endif
  endif
  if l:info.link && !empty(l:info.target)
    call add(l:lines, printf('%-13s %s', 'Symlink to', l:info.target))
  endif

  let l:width = min([100, &columns - 6])
  let s:details_id = popup_create(l:lines, {
        \ 'pos': 'center',
        \ 'border': [],
        \ 'padding': [1, 2, 1, 2],
        \ 'maxwidth': l:width,
        \ 'minwidth': min([60, l:width]),
        \ 'maxheight': max([8, &lines - 4]),
        \ 'scrollbar': 1,
        \ 'title': ' vim-files details ',
        \ 'zindex': 200,
        \ 'filtermode': 'n',
        \ 'close': 'click',
        \ 'filter': function('s:close_filter'),
        \ })
  let s:details_buf = winbufnr(s:details_id)
endfunction

function! vimfiles#ui#close_details() abort
  if s:details_valid()
    call popup_close(s:details_id)
  endif
  let s:details_id = -1
endfunction

function! s:help_lines() abort
  return [
        \ '  Navigation',
        \ '    j / k / <Down> / <Up>   move',
        \ '    h / <Left>              collapse / go to parent',
        \ '    l / <Right>             expand / open',
        \ '    o / <CR>                open file or toggle directory',
        \ '    go                      open file, stay in the tree',
        \ '    t                       open in a new tab',
        \ '    s / i                   open in vertical / horizontal split',
        \ '    p                       toggle automatic preview',
        \ '    <C-p>                   manual preview toggle',
        \ '',
        \ '  Files',
        \ '    a                       create file or directory (trailing /)',
        \ '    A                       create directory',
        \ '    r                       rename',
        \ '    d                       delete',
        \ '    c / P                   mark for copy / paste',
        \ '    y / Y                   copy path menu / absolute path',
        \ '',
        \ '  View',
        \ '    H                       toggle hidden files (scroll preview left)',
        \ '    g                       toggle git status',
        \ '    J / K                   scroll preview down / up',
        \ '    L                       scroll preview right',
        \ '    S                       sort menu',
        \ '    R / <F5>                refresh',
        \ '    I                       file details',
        \ '    f                       find current file',
        \ '    C / u                   change root / go up',
        \ '    m / ?                   menu / this help',
        \ '    q                       close tree',
        \ '',
        \ '  Directories are previewed as a listing in the same popup.',
        \ '  Preview scroll: J/K up-down, H/L left-right,',
        \ '  <C-d>/<C-u> by 10 lines, <C-e>/<C-y> by 1, <C-f>/<C-b> by 20.',
        \ '  x closes a popup; Esc also closes it (set ttimeoutlen=100 for',
        \ '  an immediate Esc). q closes the tree.',
        \ ]
endfunction

function! vimfiles#ui#help() abort
  if s:help_valid()
    call popup_close(s:help_id)
    let s:help_id = -1
    return
  endif
  let s:help_id = popup_create(s:help_lines(), {
        \ 'pos': 'center',
        \ 'border': [],
        \ 'padding': [1, 2, 1, 2],
        \ 'maxwidth': min([90, &columns - 6]),
        \ 'maxheight': max([8, &lines - 4]),
        \ 'scrollbar': 1,
        \ 'title': ' vim-files keys ',
        \ 'zindex': 200,
        \ 'filtermode': 'n',
        \ 'close': 'click',
        \ 'filter': function('s:close_filter'),
        \ })
  let s:help_buf = winbufnr(s:help_id)
endfunction

function! vimfiles#ui#escape() abort
  call vimfiles#ui#close_details()
  if s:help_valid()
    call popup_close(s:help_id)
  endif
  let s:help_id = -1
  call vimfiles#preview#close()
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set ts=2 sw=2 sts=2 et fdm=marker:
