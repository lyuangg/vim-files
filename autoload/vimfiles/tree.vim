" vim-files: the tree window, rendering and navigation

scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

let s:rendering = 0
let s:prev_win = -1

function! vimfiles#tree#find_buf() abort
  for l:info in getbufinfo()
    if getbufvar(l:info.bufnr, 'vim_files_is_tree', 0)
      return l:info.bufnr
    endif
  endfor
  return -1
endfunction

function! s:win_in_tab(buf) abort
  for l:wid in win_findbuf(a:buf)
    let l:tabwin = win_id2tabwin(l:wid)
    if !empty(l:tabwin) && l:tabwin[0] == tabpagenr()
      return l:wid
    endif
  endfor
  return -1
endfunction

function! vimfiles#tree#is_open() abort
  let l:buf = vimfiles#tree#find_buf()
  return l:buf > 0 && !empty(win_findbuf(l:buf))
endfunction

function! vimfiles#tree#is_open_here() abort
  let l:buf = vimfiles#tree#find_buf()
  return l:buf > 0 && s:win_in_tab(l:buf) > 0
endfunction

function! vimfiles#tree#win() abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return -1
  endif
  return s:win_in_tab(l:buf)
endfunction

function! s:get_vf(buf) abort
  return getbufvar(a:buf, 'vim_files_state', {})
endfunction

function! s:save_vf(buf, vf) abort
  call setbufvar(a:buf, 'vim_files_state', a:vf)
endfunction

function! s:err(msg) abort
  echohl ErrorMsg
  echomsg a:msg
  echohl None
endfunction

function! vimfiles#tree#open(...) abort
  let l:given = a:0 ? a:1 : ''
  let l:root = ''
  let l:target = ''

  if !empty(l:given)
    let l:path = vimfiles#fs#normalize(l:given)
    if empty(l:path) || empty(getftype(l:path))
      call s:err('vim-files: no such file or directory: ' . l:given)
      return
    endif
    if isdirectory(l:path)
      let l:root = l:path
    else
      let l:target = l:path
      let l:root = fnamemodify(l:path, ':h')
    endif
  endif

  let l:buf = vimfiles#tree#find_buf()
  let l:win = l:buf > 0 ? s:win_in_tab(l:buf) : -1

  if l:win > 0
    if win_getid() != l:win
      let s:prev_win = win_getid()
    endif
    call win_gotoid(l:win)
    let l:vf = s:get_vf(l:buf)
    let l:root_changed = 0
    if !empty(l:root) && l:root !=# get(l:vf, 'root', '')
      call s:set_root(l:buf, l:vf, l:root)
      let l:root_changed = 1
    endif
    if !empty(l:target)
      call s:expand_ancestors(l:vf, l:target)
      call s:save_vf(l:buf, l:vf)
      call s:render(l:target)
    elseif l:root_changed
      call s:render('')
    endif
    return
  endif

  if empty(l:root)
    if l:buf > 0
      let l:vf = s:get_vf(l:buf)
      let l:root = get(l:vf, 'root', '')
    endif
    if empty(l:root) || !isdirectory(l:root)
      let l:root = vimfiles#fs#normalize(getcwd())
    endif
  endif
  let l:root = vimfiles#fs#strip_slash(l:root)

  let l:prev = win_getid()
  let l:prev_buf = bufnr('%')
  let l:width = max([10, min([g:vim_files_width, &columns - 5])])

  if g:vim_files_side ==# 'right'
    silent! execute 'botright vertical new'
  else
    silent! execute 'topleft vertical new'
  endif
  let l:treewin = win_getid()
  silent! execute 'vertical resize ' . l:width
  setlocal winfixwidth

  if l:prev_buf > 0 && l:prev_buf != l:buf
    let s:prev_win = l:prev
  endif

  if l:buf > 0
    silent! execute 'buffer ' . l:buf
    let l:vf = s:get_vf(l:buf)
    if empty(l:vf) || !isdirectory(l:root)
      call s:init_buffer(l:root)
    elseif get(l:vf, 'root', '') !=# l:root
      call s:set_root(l:buf, l:vf, l:root)
    endif
  else
    call s:init_buffer(l:root)
  endif

  let l:buf = vimfiles#tree#find_buf()
  call s:setup_window(l:treewin)
  let l:vf = s:get_vf(l:buf)
  if !empty(l:target)
    call s:expand_ancestors(l:vf, l:target)
    call s:save_vf(l:buf, l:vf)
  endif
  call s:render(l:target)
  call win_gotoid(l:treewin)
endfunction

function! s:init_buffer(root) abort
  enew
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal nobuflisted
  setlocal undolevels=-1
  silent! noautocmd keepalt file [vim-files]
  setlocal filetype=vim-files

  let b:vim_files_is_tree = 1
  let b:vim_files_state = {
        \ 'root': a:root,
        \ 'expanded': {},
        \ 'sort': g:vim_files_sort,
        \ 'dirs_first': g:vim_files_sort_dirs_first ? 1 : 0,
        \ 'sort_reverse': g:vim_files_sort_reverse ? 1 : 0,
        \ 'sort_case_sensitive': g:vim_files_sort_case_sensitive ? 1 : 0,
        \ 'show_hidden': g:vim_files_show_hidden ? 1 : 0,
        \ 'show_git': g:vim_files_show_git ? 1 : 0,
        \ 'auto_preview': g:vim_files_auto_preview ? 1 : 0,
        \ 'git': {'is_repo': 0, 'branch': '', 'files': {}, 'dirs': {}, 'count': 0},
        \ 'git_loaded': 0,
        \ 'nodes': [],
        \ 'render': {'lines': [], 'segments': []},
        \ 'matches': {},
        \ 'cursor_path': '',
        \ 'copy_path': '',
        \ }
  let b:vim_files_state.expanded[a:root] = 1
  call s:setup_autocmds()
  call s:setup_mappings()
endfunction

function! s:setup_autocmds() abort
  augroup vim_files_tree
    autocmd! * <buffer>
    autocmd CursorMoved <buffer> call vimfiles#tree#on_cursor_moved()
    autocmd WinLeave <buffer> call vimfiles#preview#close()
    autocmd BufWinEnter <buffer> call vimfiles#tree#on_win_enter()
    autocmd WinEnter <buffer> call vimfiles#tree#on_win_enter()
  augroup END
endfunction

function! s:setup_mappings() abort
  nnoremap <buffer> <silent> <CR> :<C-u>call vimfiles#ui#action('open')<CR>
  nnoremap <buffer> <silent> <2-LeftMouse> :<C-u>call vimfiles#ui#action('open')<CR>
  nnoremap <buffer> <silent> o :<C-u>call vimfiles#ui#action('open')<CR>
  nnoremap <buffer> <silent> go :<C-u>call vimfiles#ui#action('open_keep_focus')<CR>
  nnoremap <buffer> <silent> l :<C-u>call vimfiles#ui#action('expand_or_open')<CR>
  nnoremap <buffer> <silent> h :<C-u>call vimfiles#ui#action('collapse_or_parent')<CR>
  nnoremap <buffer> <silent> <Right> :<C-u>call vimfiles#ui#action('expand_or_open')<CR>
  nnoremap <buffer> <silent> <Left> :<C-u>call vimfiles#ui#action('collapse_or_parent')<CR>
  nnoremap <buffer> <silent> t :<C-u>call vimfiles#ui#action('tab')<CR>
  nnoremap <buffer> <silent> s :<C-u>call vimfiles#ui#action('vsplit')<CR>
  nnoremap <buffer> <silent> i :<C-u>call vimfiles#ui#action('split')<CR>
  nnoremap <buffer> <silent> p :<C-u>call vimfiles#ui#action('toggle_auto_preview')<CR>
  nnoremap <buffer> <silent> <C-p> :<C-u>call vimfiles#ui#action('preview')<CR>
  nnoremap <buffer> <silent> a :<C-u>call vimfiles#ui#action('create')<CR>
  nnoremap <buffer> <silent> A :<C-u>call vimfiles#ui#action('create_dir')<CR>
  nnoremap <buffer> <silent> r :<C-u>call vimfiles#ui#action('rename')<CR>
  nnoremap <buffer> <silent> d :<C-u>call vimfiles#ui#action('delete')<CR>
  nnoremap <buffer> <silent> c :<C-u>call vimfiles#ui#action('copy')<CR>
  nnoremap <buffer> <silent> P :<C-u>call vimfiles#ui#action('paste')<CR>
  nnoremap <buffer> <silent> y :<C-u>call vimfiles#ui#action('copy_menu')<CR>
  nnoremap <buffer> <silent> Y :<C-u>call vimfiles#ui#action('copy_abspath')<CR>
  nnoremap <expr> <buffer> <silent> H vimfiles#preview#is_open()
        \ ? ':call vimfiles#preview#scroll_h(-' . v:count1 . ")\<CR>"
        \ : ":call vimfiles#ui#action('toggle_hidden')\<CR>"
  nnoremap <expr> <buffer> <silent> J vimfiles#preview#is_open()
        \ ? ':call vimfiles#preview#scroll(' . v:count1 . ")\<CR>" : ''
  nnoremap <expr> <buffer> <silent> K vimfiles#preview#is_open()
        \ ? ':call vimfiles#preview#scroll(-' . v:count1 . ")\<CR>" : ''
  nnoremap <expr> <buffer> <silent> L vimfiles#preview#is_open()
        \ ? ':call vimfiles#preview#scroll_h(' . v:count1 . ")\<CR>" : ''
  nnoremap <buffer> <silent> I :<C-u>call vimfiles#ui#action('details')<CR>
  nnoremap <buffer> <silent> S :<C-u>call vimfiles#ui#action('sort_menu')<CR>
  nnoremap <buffer> <silent> f :<C-u>call vimfiles#ui#action('find')<CR>
  nnoremap <buffer> <silent> R :<C-u>call vimfiles#ui#action('refresh')<CR>
  nnoremap <buffer> <silent> <F5> :<C-u>call vimfiles#ui#action('refresh')<CR>
  nnoremap <buffer> <silent> C :<C-u>call vimfiles#ui#action('change_root')<CR>
  nnoremap <buffer> <silent> u :<C-u>call vimfiles#ui#action('up_root')<CR>
  nnoremap <buffer> <silent> m :<C-u>call vimfiles#ui#menu()<CR>
  nnoremap <buffer> <silent> ? :<C-u>call vimfiles#ui#help()<CR>
  nnoremap <buffer> <silent> q :<C-u>call vimfiles#tree#close()<CR>

  nnoremap <expr> <buffer> <silent> <C-d> vimfiles#preview#is_open()
        \ ? ':call vimfiles#preview#scroll(' . (v:count1 * 10) . ")\<CR>" : "\<C-d>"
  nnoremap <expr> <buffer> <silent> <C-u> vimfiles#preview#is_open()
        \ ? ':call vimfiles#preview#scroll(' . (v:count1 * -10) . ")\<CR>" : "\<C-u>"
  nnoremap <expr> <buffer> <silent> <C-e> vimfiles#preview#is_open()
        \ ? ':call vimfiles#preview#scroll(1)' . "\<CR>" : "\<C-e>"
  nnoremap <expr> <buffer> <silent> <C-y> vimfiles#preview#is_open()
        \ ? ':call vimfiles#preview#scroll(-1)' . "\<CR>" : "\<C-y>"
  nnoremap <expr> <buffer> <silent> <C-f> vimfiles#preview#is_open()
        \ ? ':call vimfiles#preview#scroll(' . (v:count1 * 20) . ")\<CR>" : "\<C-f>"
  nnoremap <expr> <buffer> <silent> <C-b> vimfiles#preview#is_open()
        \ ? ':call vimfiles#preview#scroll(' . (v:count1 * -20) . ")\<CR>" : "\<C-b>"
endfunction

function! s:setup_window(win) abort
  if a:win <= 0 || !win_id2win(a:win)
    return
  endif
  call win_execute(a:win, 'setlocal nonumber norelativenumber nolist nospell nowrap nobuflisted')
  call win_execute(a:win, 'setlocal foldcolumn=0 signcolumn=no colorcolumn=')
  let l:cursorline = get(g:, 'vim_files_cursorline', 1) ? 'cursorline' : 'nocursorline'
  call win_execute(a:win, 'setlocal ' . l:cursorline . ' scrolloff=0 winfixwidth')
  let l:vf = s:get_vf(vimfiles#tree#find_buf())
  call s:update_statusline(a:win, l:vf)
endfunction

function! vimfiles#tree#close() abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:win = s:win_in_tab(l:buf)
  if l:win <= 0
    call s:err('vim-files: tree is not open in this tab')
    return
  endif
  call vimfiles#ui#escape()
  let l:prev = s:prev_win
  if winnr('$') > 1
    call win_gotoid(l:win)
    close
    if l:prev > 0 && win_id2win(l:prev) > 0 && winbufnr(l:prev) != l:buf
      call win_gotoid(l:prev)
    endif
  else
    call win_gotoid(l:win)
    enew
  endif
endfunction

function! vimfiles#tree#root() abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return ''
  endif
  return get(s:get_vf(l:buf), 'root', '')
endfunction

function! vimfiles#tree#sort_mode() abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return g:vim_files_sort
  endif
  return get(s:get_vf(l:buf), 'sort', g:vim_files_sort)
endfunction

function! vimfiles#tree#current_node() abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return {}
  endif
  let l:vf = s:get_vf(l:buf)
  if bufnr('%') == l:buf
    return get(get(l:vf, 'nodes', []), line('.') - 1, {})
  endif
  for l:node in get(l:vf, 'nodes', [])
    if l:node.path ==# get(l:vf, 'cursor_path', '')
      return l:node
    endif
  endfor
  return {}
endfunction

function! s:node_by_path(vf, path) abort
  for l:node in get(a:vf, 'nodes', [])
    if l:node.path ==# a:path
      return l:node
    endif
  endfor
  return {}
endfunction

function! vimfiles#tree#git_code(path) abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return ''
  endif
  let l:vf = s:get_vf(l:buf)
  let l:git = get(l:vf, 'git', {})
  if isdirectory(a:path)
    return get(get(l:git, 'dirs', {}), a:path, '')
  endif
  return get(get(l:git, 'files', {}), a:path, '')
endfunction

function! vimfiles#tree#set_copy(path) abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  let l:vf.copy_path = a:path
  call s:save_vf(l:buf, l:vf)
endfunction

function! vimfiles#tree#get_copy() abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return ''
  endif
  return get(s:get_vf(l:buf), 'copy_path', '')
endfunction

function! s:list_dir(vf, dir) abort
  try
    let l:names = readdir(a:dir)
  catch
    return []
  endtry
  let l:names = filter(l:names, '!s:ignored(a:vf, v:val)')
  let l:nodes = []
  for l:name in l:names
    let l:path = vimfiles#fs#join(a:dir, l:name)
    call add(l:nodes, s:make_node(a:vf, l:path, l:name, 0))
  endfor
  return s:sort_nodes(l:nodes, a:vf)
endfunction

function! s:ignored(vf, name) abort
  if a:name ==# '.' || a:name ==# '..'
    return 1
  endif
  if a:name[0] ==# '.' && !get(a:vf, 'show_hidden', 0)
    return 1
  endif
  for l:pat in g:vim_files_ignore
    if empty(l:pat)
      continue
    endif
    if a:name ==# l:pat || match(a:name, glob2regpat(l:pat)) >= 0
      return 1
    endif
  endfor
  return 0
endfunction

function! s:make_node(vf, path, name, depth) abort
  let l:is_dir = isdirectory(a:path)
  let l:code = ''
  if get(a:vf, 'show_git', 0)
    let l:git = get(a:vf, 'git', {})
    if l:is_dir
      let l:code = get(get(l:git, 'dirs', {}), a:path, '')
    else
      let l:code = get(get(l:git, 'files', {}), a:path, '')
    endif
  endif
  return {
        \ 'path': a:path,
        \ 'name': a:name,
        \ 'is_dir': l:is_dir,
        \ 'depth': a:depth,
        \ 'is_link': getftype(a:path) ==# 'link',
        \ 'git': l:code,
        \ }
endfunction

function! s:add_children(vf, nodes, dir, depth) abort
  for l:node in s:list_dir(a:vf, a:dir)
    let l:node.depth = a:depth
    call add(a:nodes, l:node)
    if l:node.is_dir && get(a:vf.expanded, l:node.path, 0)
      call s:add_children(a:vf, a:nodes, l:node.path, a:depth + 1)
    endif
  endfor
endfunction

function! s:build_nodes(vf) abort
  let l:nodes = []
  let l:root = a:vf.root
  let l:name = fnamemodify(l:root, ':t')
  if empty(l:name)
    let l:name = l:root
  endif
  let l:root_node = s:make_node(a:vf, l:root, l:name, 0)
  let l:root_node.is_dir = 1
  call add(l:nodes, l:root_node)
  if get(a:vf.expanded, l:root, 1)
    call s:add_children(a:vf, l:nodes, l:root, 1)
  endif
  return l:nodes
endfunction

function! s:node_size(node) abort
  if !has_key(a:node, 'size')
    let a:node.size = getfsize(a:node.path)
  endif
  return a:node.size
endfunction

function! s:node_mtime(node) abort
  if !has_key(a:node, 'mtime')
    let a:node.mtime = getftime(a:node.path)
  endif
  return a:node.mtime
endfunction

function! s:cmp_num(a, b) abort
  return a:a == a:b ? 0 : (a:a < a:b ? -1 : 1)
endfunction

function! s:cmp_str(a, b) abort
  return a:a ==# a:b ? 0 : (a:a <# a:b ? -1 : 1)
endfunction

function! s:node_compare(ctx, a, b) abort
  if a:ctx.dirs_first && a:a.is_dir != a:b.is_dir
    return a:a.is_dir ? -1 : 1
  endif
  let l:res = 0
  if a:ctx.mode ==# 'extension'
    let l:ea = tolower(fnamemodify(a:a.name, ':e'))
    let l:eb = tolower(fnamemodify(a:b.name, ':e'))
    let l:res = s:cmp_str(l:ea, l:eb)
  elseif a:ctx.mode ==# 'size'
    let l:res = s:cmp_num(s:node_size(a:a), s:node_size(a:b))
  elseif a:ctx.mode ==# 'mtime'
    let l:res = s:cmp_num(s:node_mtime(a:a), s:node_mtime(a:b))
  endif
  if l:res == 0
    let l:na = a:ctx.case_sensitive ? a:a.name : tolower(a:a.name)
    let l:nb = a:ctx.case_sensitive ? a:b.name : tolower(a:b.name)
    let l:res = s:cmp_str(l:na, l:nb)
  endif
  return a:ctx.reverse ? -l:res : l:res
endfunction

function! s:sort_nodes(nodes, vf) abort
  let l:mode = get(a:vf, 'sort', 'name')
  let l:reverse = get(a:vf, 'sort_reverse', 0)
  let l:dirs_first = get(a:vf, 'dirs_first', 1)

  if l:mode ==# 'none'
    let l:dirs = filter(copy(a:nodes), 'v:val.is_dir')
    let l:files = filter(copy(a:nodes), '!v:val.is_dir')
    if l:reverse
      call reverse(l:dirs)
      call reverse(l:files)
    endif
    if l:dirs_first || l:reverse
      if l:dirs_first
        return l:dirs + l:files
      endif
      return reverse(l:dirs + l:files)
    endif
    return a:nodes
  endif

  let l:ctx = {
        \ 'mode': l:mode,
        \ 'reverse': l:reverse,
        \ 'dirs_first': l:dirs_first,
        \ 'case_sensitive': get(a:vf, 'sort_case_sensitive', 0),
        \ }
  return sort(a:nodes, function('s:node_compare', [l:ctx]))
endfunction

function! s:icon(node) abort
  if !get(g:, 'vim_files_icons', 1)
    return ''
  endif
  if !exists('*WebDevIconsGetFileTypeSymbol')
    return ''
  endif
  try
    if a:node.is_dir
      let l:icon = WebDevIconsGetFileTypeSymbol(a:node.name, 1)
    else
      let l:icon = WebDevIconsGetFileTypeSymbol(a:node.name, 0)
    endif
  catch
    return ''
  endtry
  return substitute(l:icon, '\s\+$', '', '')
endfunction

function! s:active_file(vf) abort
  let l:tree_buf = vimfiles#tree#find_buf()
  let l:alt = winnr('#')
  if l:alt > 0 && l:alt != winnr()
    let l:b = winbufnr(l:alt)
    if l:b > 0 && l:b != l:tree_buf && empty(getbufvar(l:b, '&buftype'))
      let l:name = bufname(l:b)
      if !empty(l:name)
        return vimfiles#fs#normalize(l:name)
      endif
    endif
  endif
  if s:prev_win > 0 && win_id2win(s:prev_win) > 0
    let l:b = winbufnr(s:prev_win)
    if l:b > 0 && l:b != l:tree_buf && empty(getbufvar(l:b, '&buftype'))
      let l:name = bufname(l:b)
      if !empty(l:name)
        return vimfiles#fs#normalize(l:name)
      endif
    endif
  endif
  for l:info in getwininfo()
    if l:info.tabnr == tabpagenr() && l:info.bufnr != l:tree_buf
          \ && empty(getbufvar(l:info.bufnr, '&buftype'))
      let l:name = bufname(l:info.bufnr)
      if !empty(l:name)
        return vimfiles#fs#normalize(l:name)
      endif
    endif
  endfor
  return ''
endfunction

function! s:format_node(node, vf) abort
  let l:indent = repeat(get(g:, 'vim_files_indent', '  '), a:node.depth)
  let l:arrows = get(g:, 'vim_files_dir_arrows', ['▸', '▾'])
  if type(l:arrows) != v:t_list || len(l:arrows) < 2
    let l:arrows = ['▸', '▾']
  endif
  if a:node.is_dir
    let l:arrow = get(a:vf.expanded, a:node.path, 0) ? l:arrows[1] : l:arrows[0]
  else
    let l:arrow = ' '
  endif
  let l:icon = s:icon(a:node)

  let l:line = l:indent . l:arrow . ' '
  let l:seg = {
        \ 'lnum': 0,
        \ 'line': '',
        \ 'arrow_col': strlen(l:indent) + 1,
        \ 'arrow_len': strlen(l:arrow),
        \ 'arrow_group': a:node.is_dir ? 'VimFilesDirArrow' : '',
        \ 'icon_col': 0,
        \ 'icon_len': 0,
        \ 'name_col': 0,
        \ 'name_len': 0,
        \ 'name_group': '',
        \ 'git_col': 0,
        \ 'git_len': 0,
        \ 'git_group': '',
        \ 'path': a:node.path,
        \ 'is_dir': a:node.is_dir,
        \ }
  if !empty(l:icon)
    let l:seg.icon_col = strlen(l:line) + 1
    let l:seg.icon_len = strlen(l:icon)
    let l:line .= l:icon . ' '
  endif
  let l:name = a:node.name
  if a:node.is_dir && l:name !~# '/$'
    let l:name .= '/'
  endif
  let l:seg.name_col = strlen(l:line) + 1
  let l:seg.name_len = strlen(l:name)
  let l:line .= l:name

  if a:node.is_dir
    let l:seg.name_group = a:node.depth == 0 ? 'VimFilesRoot' : 'VimFilesDir'
  elseif a:node.is_link
    let l:seg.name_group = 'VimFilesLink'
  endif

  let l:sym = vimfiles#git#symbol(get(a:node, 'git', ''))
  if !empty(l:sym)
    let l:line .= ' ' . l:sym
    let l:seg.git_col = strlen(l:line) - strlen(l:sym) + 1
    let l:seg.git_len = strlen(l:sym)
    let l:seg.git_group = vimfiles#git#highlight(a:node.git)
  endif

  let l:seg.line = l:line
  return l:seg
endfunction

function! s:build_render_data(nodes, vf) abort
  let l:segments = []
  let l:lines = []
  let l:lnum = 0
  for l:node in a:nodes
    let l:lnum += 1
    let l:seg = s:format_node(l:node, a:vf)
    let l:seg.lnum = l:lnum
    call add(l:segments, l:seg)
    call add(l:lines, l:seg.line)
  endfor
  return {'lines': l:lines, 'segments': l:segments}
endfunction

function! s:write_buffer(buf, lines) abort
  call setbufvar(a:buf, '&modifiable', 1)
  let l:old = get(getbufinfo(a:buf), 0, {'linecount': 0}).linecount
  try
    if empty(a:lines)
      if l:old > 0
        call deletebufline(a:buf, 1, '$')
      endif
    else
      call setbufline(a:buf, 1, a:lines)
      if l:old > len(a:lines)
        call deletebufline(a:buf, len(a:lines) + 1, l:old)
      endif
    endif
  finally
    call setbufvar(a:buf, '&modified', 0)
    call setbufvar(a:buf, '&modifiable', 0)
  endtry
endfunction

function! s:apply_highlights(win, vf, render) abort
  if a:win <= 0 || !win_id2win(a:win)
    return
  endif
  for l:id in get(get(a:vf, 'matches', {}), a:win, [])
    silent! call matchdelete(l:id, a:win)
  endfor
  if !has_key(a:vf, 'matches')
    let a:vf.matches = {}
  endif
  let a:vf.matches[a:win] = []

  let l:active = s:active_file(a:vf)
  let l:groups = {}
  for l:seg in get(a:render, 'segments', [])
    call s:addpos(l:groups, l:seg.name_group, [l:seg.lnum, l:seg.name_col, l:seg.name_len])
    call s:addpos(l:groups, l:seg.arrow_group, [l:seg.lnum, l:seg.arrow_col, l:seg.arrow_len])
    if l:seg.icon_len > 0
      call s:addpos(l:groups, 'VimFilesIcon', [l:seg.lnum, l:seg.icon_col, l:seg.icon_len])
    endif
    call s:addpos(l:groups, l:seg.git_group, [l:seg.lnum, l:seg.git_col, l:seg.git_len])
    if !empty(l:active) && !l:seg.is_dir && l:seg.path ==# l:active
      call s:addpos(l:groups, 'VimFilesCurrentFile', [l:seg.lnum, l:seg.name_col, l:seg.name_len])
    endif
  endfor

  for [l:group, l:positions] in items(l:groups)
    if empty(l:group) || empty(l:positions)
      continue
    endif
    let l:priority = l:group ==# 'VimFilesCurrentFile' ? 15
          \ : (l:group =~# '^VimFilesGit' ? 12 : (l:group ==# 'VimFilesIcon' ? 11 : 10))
    let l:id = matchaddpos(l:group, l:positions, l:priority, -1, {'window': a:win})
    if l:id > 0
      call add(a:vf.matches[a:win], l:id)
    endif
  endfor
endfunction

function! s:addpos(groups, group, pos) abort
  if empty(a:group) || a:pos[2] <= 0
    return
  endif
  if !has_key(a:groups, a:group)
    let a:groups[a:group] = []
  endif
  call add(a:groups[a:group], a:pos)
endfunction

function! s:line_of_path(nodes, path) abort
  let l:i = 0
  for l:node in a:nodes
    let l:i += 1
    if l:node.path ==# a:path
      return l:i
    endif
  endfor
  return 0
endfunction

function! s:place_cursor(win, vf, target) abort
  let l:lnum = 0
  let l:want = a:target
  if empty(l:want)
    let l:want = get(a:vf, 'cursor_path', '')
  endif
  let l:nodes = get(a:vf, 'nodes', [])
  let l:guard = 0
  while l:lnum == 0 && !empty(l:want)
    let l:lnum = s:line_of_path(l:nodes, l:want)
    if l:lnum > 0
      break
    endif
    let l:parent = fnamemodify(l:want, ':h')
    if l:parent ==# l:want
      break
    endif
    let l:want = l:parent
    let l:guard += 1
    if l:guard > 512
      break
    endif
  endwhile
  if l:lnum == 0
    let l:lnum = 1
  endif
  let l:count = len(get(a:vf, 'nodes', []))
  if l:count > 0
    let l:lnum = min([l:count, max([1, l:lnum])])
  endif
  call win_execute(a:win, 'call cursor(' . l:lnum . ', 1)')
  if l:lnum > 0 && l:lnum <= len(l:nodes)
    let a:vf.cursor_path = l:nodes[l:lnum - 1].path
  endif
endfunction

function! s:update_statusline(win, vf) abort
  if a:win <= 0 || !win_id2win(a:win)
    return
  endif
  let l:root = get(a:vf, 'root', '')
  let l:name = fnamemodify(l:root, ':t')
  if empty(l:name)
    let l:name = l:root
  endif
  let l:extra = ''
  let l:git = get(a:vf, 'git', {})
  if get(l:git, 'is_repo', 0) && !empty(get(l:git, 'branch', ''))
    let l:extra .= '  ' . l:git.branch
  endif
  if get(a:vf, 'show_hidden', 0)
    let l:extra .= '  [hidden]'
  endif
  if !get(a:vf, 'show_git', 1)
    let l:extra .= '  [no git]'
  endif
  let l:line = ' vim-files  ' . l:name . l:extra . ' '
  let l:line = substitute(l:line, '%', '%%', 'g')
  call setwinvar(a:win, '&statusline', l:line)
endfunction

function! s:render(target) abort
  if s:rendering
    return
  endif
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:win = s:win_in_tab(l:buf)
  if l:win <= 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  if empty(l:vf)
    return
  endif

  let s:rendering = 1
  try
    let l:target = a:target
    if empty(l:target)
      let l:target = get(l:vf, 'cursor_path', '')
    endif

    if get(l:vf, 'show_git', 0)
      if !get(l:vf, 'git_loaded', 0)
        let l:vf.git = vimfiles#git#load(l:vf.root)
        let l:vf.git_loaded = 1
      endif
    else
      let l:vf.git = {'is_repo': 0, 'branch': '', 'files': {}, 'dirs': {}, 'count': 0}
    endif

    let l:nodes = s:build_nodes(l:vf)
    let l:render = s:build_render_data(l:nodes, l:vf)
    call s:write_buffer(l:buf, l:render.lines)
    let l:vf.nodes = l:nodes
    let l:vf.render = l:render
    call s:save_vf(l:buf, l:vf)
    call s:apply_highlights(l:win, l:vf, l:render)
    call s:place_cursor(l:win, l:vf, l:target)
    call s:save_vf(l:buf, l:vf)
    call s:update_statusline(l:win, l:vf)
    if l:win == win_getid()
      silent! call vimfiles#preview#on_cursor_moved()
    endif
  finally
    let s:rendering = 0
  endtry
endfunction

function! vimfiles#tree#refresh(...) abort
  let l:opts = (a:0 && type(a:1) == v:t_dict) ? a:1 : {}
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  if empty(l:vf)
    return
  endif
  if get(l:opts, 'git', 0)
    let l:vf.git_loaded = 0
  endif
  let l:cursor = get(l:opts, 'cursor', '')
  if !empty(l:cursor) && get(l:opts, 'expand', 0)
    call s:expand_ancestors(l:vf, l:cursor)
  endif
  call s:save_vf(l:buf, l:vf)
  call s:render(l:cursor)
endfunction

function! s:expand_ancestors(vf, path) abort
  let l:path = vimfiles#fs#normalize(a:path)
  if empty(l:path) || !vimfiles#fs#is_under(l:path, a:vf.root)
    return
  endif
  let l:dir = isdirectory(l:path) ? l:path : fnamemodify(l:path, ':h')
  let l:guard = 0
  while 1
    let a:vf.expanded[l:dir] = 1
    if l:dir ==# a:vf.root
      break
    endif
    let l:dir = fnamemodify(l:dir, ':h')
    let l:guard += 1
    if l:guard > 512
      break
    endif
  endwhile
endfunction

function! s:set_root(buf, vf, root) abort
  let a:vf.root = a:root
  let a:vf.expanded = {}
  let a:vf.expanded[a:root] = 1
  let a:vf.git_loaded = 0
  let a:vf.cursor_path = ''
  let a:vf.nodes = []
  let a:vf.render = {'lines': [], 'segments': []}
  call s:save_vf(a:buf, a:vf)
endfunction

function! vimfiles#tree#set_root(path) abort
  let l:path = vimfiles#fs#normalize(a:path)
  if empty(l:path) || !isdirectory(l:path)
    call s:err('vim-files: not a directory: ' . a:path)
    return
  endif
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  call s:set_root(l:buf, l:vf, l:path)
  call s:render('')
endfunction

function! vimfiles#tree#up_root() abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  let l:old = l:vf.root
  let l:parent = fnamemodify(l:old, ':h')
  if l:parent ==# l:old || empty(l:parent)
    call s:err('vim-files: already at the filesystem root')
    return
  endif
  let l:vf.root = l:parent
  let l:vf.expanded = {}
  let l:vf.expanded[l:parent] = 1
  let l:vf.expanded[l:old] = 1
  let l:vf.git_loaded = 0
  let l:vf.cursor_path = l:old
  call s:save_vf(l:buf, l:vf)
  call s:render(l:old)
endfunction

function! vimfiles#tree#toggle_dir(path) abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  if !isdirectory(a:path)
    return
  endif
  if get(l:vf.expanded, a:path, 0)
    silent! call remove(l:vf.expanded, a:path)
  else
    let l:vf.expanded[a:path] = 1
  endif
  call s:save_vf(l:buf, l:vf)
  call s:render(a:path)
endfunction

function! vimfiles#tree#expand(path) abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0 || !isdirectory(a:path)
    return
  endif
  let l:vf = s:get_vf(l:buf)
  if !get(l:vf.expanded, a:path, 0)
    let l:vf.expanded[a:path] = 1
    call s:save_vf(l:buf, l:vf)
    call s:render(a:path)
  endif
endfunction

function! vimfiles#tree#collapse(path) abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  if isdirectory(a:path) && get(l:vf.expanded, a:path, 0)
    silent! call remove(l:vf.expanded, a:path)
    call s:save_vf(l:buf, l:vf)
    call s:render(a:path)
  endif
endfunction

function! vimfiles#tree#goto_parent(path) abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:win = s:win_in_tab(l:buf)
  if l:win <= 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  let l:parent = fnamemodify(a:path, ':h')
  if l:parent ==# a:path
    return
  endif
  call s:place_cursor(l:win, l:vf, l:parent)
  call s:save_vf(l:buf, l:vf)
  call win_execute(l:win, 'normal! zz')
  silent! call vimfiles#preview#on_cursor_moved()
endfunction

function! vimfiles#tree#goto_path(path) abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:win = s:win_in_tab(l:buf)
  if l:win <= 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  call s:place_cursor(l:win, l:vf, a:path)
  call s:save_vf(l:buf, l:vf)
  call win_gotoid(l:win)
  call win_execute(l:win, 'normal! zz')
  silent! call vimfiles#preview#on_cursor_moved()
endfunction

function! s:target_window() abort
  let l:tree_buf = vimfiles#tree#find_buf()
  if bufnr('%') == l:tree_buf
    let l:alt = winnr('#')
    if l:alt > 0 && l:alt != winnr()
      let l:altbuf = winbufnr(l:alt)
      if l:altbuf > 0 && l:altbuf != l:tree_buf
            \ && empty(getbufvar(l:altbuf, '&buftype'))
        return win_getid(l:alt)
      endif
    endif
  endif
  if s:prev_win > 0
    let l:tw = win_id2tabwin(s:prev_win)
    if !empty(l:tw) && l:tw[0] == tabpagenr()
          \ && winbufnr(s:prev_win) != l:tree_buf
          \ && empty(getbufvar(winbufnr(s:prev_win), '&buftype'))
      return s:prev_win
    endif
  endif
  for l:info in getwininfo()
    if l:info.tabnr == tabpagenr() && l:info.winid != win_getid()
          \ && l:info.bufnr != l:tree_buf
          \ && empty(getbufvar(l:info.bufnr, '&buftype'))
      return l:info.winid
    endif
  endfor
  return 0
endfunction

function! vimfiles#tree#open_file(path, mode, ...) abort
  let l:keep_focus = a:0 ? a:1 : 0
  if isdirectory(a:path)
    call vimfiles#tree#toggle_dir(a:path)
    return
  endif
  let l:treewin = s:win_in_tab(vimfiles#tree#find_buf())
  silent! call vimfiles#ui#escape()
  let l:path = fnameescape(a:path)

  if a:mode ==# 'tab'
    if !l:keep_focus && get(g:, 'vim_files_close_on_open', 0)
          \ && vimfiles#tree#is_open_here()
      call vimfiles#tree#close()
    endif
    silent! execute 'tabnew ' . l:path
    let s:prev_win = win_getid()
    call vimfiles#tree#refresh_current_highlight()
    if l:keep_focus && l:treewin > 0
      call win_gotoid(l:treewin)
    endif
    return
  endif

  if winnr('$') == 1 && bufnr('%') == vimfiles#tree#find_buf()
    if a:mode ==# 'split'
      silent! execute 'belowright split ' . l:path
    else
      silent! execute 'rightbelow vsplit ' . l:path
    endif
    let s:prev_win = win_getid()
    call vimfiles#tree#refresh_current_highlight()
    if l:keep_focus && l:treewin > 0
      call win_gotoid(l:treewin)
    endif
    if !l:keep_focus && get(g:, 'vim_files_close_on_open', 0)
      call vimfiles#tree#close()
    endif
    return
  endif

  let l:target = s:target_window()
  if l:target <= 0
    if a:mode ==# 'split'
      silent! execute 'belowright split ' . l:path
    else
      silent! execute 'rightbelow vsplit ' . l:path
    endif
  else
    call win_gotoid(l:target)
    if a:mode ==# 'vsplit'
      silent! execute 'vsplit ' . l:path
    elseif a:mode ==# 'split'
      silent! execute 'split ' . l:path
    else
      silent! execute 'hide edit ' . l:path
    endif
  endif
  let s:prev_win = win_getid()
  call vimfiles#tree#refresh_current_highlight()
  if l:keep_focus && l:treewin > 0
    call win_gotoid(l:treewin)
  endif
  if !l:keep_focus && get(g:, 'vim_files_close_on_open', 0)
    call vimfiles#tree#close()
  endif
endfunction

function! vimfiles#tree#refresh_current_highlight() abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:win = s:win_in_tab(l:buf)
  if l:win <= 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  call s:apply_highlights(l:win, l:vf, get(l:vf, 'render', {'segments': []}))
  call s:save_vf(l:buf, l:vf)
endfunction

function! vimfiles#tree#activate(path) abort
  if empty(a:path)
    return
  endif
  if isdirectory(a:path)
    call vimfiles#tree#toggle_dir(a:path)
  else
    call vimfiles#tree#open_file(a:path, 'edit')
  endif
endfunction

function! vimfiles#tree#find() abort
  let l:buf = vimfiles#tree#find_buf()
  let l:vf = l:buf > 0 ? s:get_vf(l:buf) : {}
  let l:file = ''

  if l:buf > 0 && bufnr('%') == l:buf
    let l:file = s:active_file(l:vf)
  elseif empty(&buftype) && !empty(expand('%:p'))
    let l:file = vimfiles#fs#normalize(expand('%:p'))
  else
    call s:err('vim-files: current buffer has no file name')
    return
  endif

  if empty(l:file)
    call s:err('vim-files: could not determine the current file')
    return
  endif

  if l:buf < 0 || !vimfiles#tree#is_open_here()
    let l:root = vimfiles#fs#normalize(getcwd())
    if !vimfiles#fs#is_under(l:file, l:root)
      let l:root = fnamemodify(l:file, ':h')
    endif
    call vimfiles#tree#open(l:root)
    let l:buf = vimfiles#tree#find_buf()
    let l:vf = s:get_vf(l:buf)
  else
    call win_gotoid(s:win_in_tab(l:buf))
    let l:vf = s:get_vf(l:buf)
    if !vimfiles#fs#is_under(l:file, l:vf.root)
      call s:set_root(l:buf, l:vf, fnamemodify(l:file, ':h'))
    endif
  endif

  if empty(l:vf)
    return
  endif
  call s:expand_ancestors(l:vf, l:file)
  let l:vf.cursor_path = l:file
  call s:save_vf(l:buf, l:vf)
  call s:render(l:file)
  let l:win = s:win_in_tab(l:buf)
  if l:win > 0
    call win_gotoid(l:win)
    call win_execute(l:win, 'normal! zz')
  endif
endfunction

function! vimfiles#tree#toggle_hidden() abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  let l:vf.show_hidden = !get(l:vf, 'show_hidden', 0)
  call s:save_vf(l:buf, l:vf)
  call s:render('')
  call vimfiles#ui#info('vim-files: hidden files '
        \ . (l:vf.show_hidden ? 'shown' : 'hidden'))
endfunction

function! vimfiles#tree#toggle_git() abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  let l:vf.show_git = !get(l:vf, 'show_git', 0)
  let l:vf.git_loaded = 0
  call s:save_vf(l:buf, l:vf)
  call s:render('')
  call vimfiles#ui#info('vim-files: git status '
        \ . (l:vf.show_git ? 'enabled' : 'disabled'))
endfunction

function! vimfiles#tree#toggle_auto_preview() abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  let l:vf.auto_preview = !get(l:vf, 'auto_preview', 0)
  call s:save_vf(l:buf, l:vf)
  if l:vf.auto_preview
    silent! call vimfiles#preview#on_cursor_moved()
  else
    call vimfiles#preview#close()
  endif
  call vimfiles#ui#info('vim-files: auto preview '
        \ . (l:vf.auto_preview ? 'enabled' : 'disabled'))
endfunction

function! vimfiles#tree#set_sort(mode) abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  let l:vf.sort = a:mode
  call s:save_vf(l:buf, l:vf)
  call s:render('')
  call vimfiles#ui#info('vim-files: sorting by ' . a:mode)
endfunction

function! vimfiles#tree#on_cursor_moved() abort
  if !get(b:, 'vim_files_is_tree', 0)
    return
  endif
  let l:vf = get(b:, 'vim_files_state', {})
  let l:node = get(get(l:vf, 'nodes', []), line('.') - 1, {})
  let l:vf.cursor_path = get(l:node, 'path', '')
  let b:vim_files_state = l:vf
  silent! call vimfiles#ui#close_details()
  silent! call vimfiles#preview#on_cursor_moved()
endfunction

function! vimfiles#tree#on_win_enter() abort
  if !get(b:, 'vim_files_is_tree', 0)
    return
  endif
  call s:setup_window(win_getid())
  let l:vf = get(b:, 'vim_files_state', {})
  call s:apply_highlights(win_getid(), l:vf, get(l:vf, 'render', {'segments': []}))
  let b:vim_files_state = l:vf
  call s:update_statusline(win_getid(), l:vf)
  if !empty(get(l:vf, 'nodes', []))
    call s:place_cursor(win_getid(), l:vf, get(l:vf, 'cursor_path', ''))
    let b:vim_files_state = l:vf
  endif
endfunction

function! vimfiles#tree#apply_renamed(old, new) abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  let l:expanded = {}
  for l:key in keys(get(l:vf, 'expanded', {}))
    if l:key ==# a:old
      let l:expanded[a:new] = 1
    elseif stridx(l:key, a:old . '/') == 0
      let l:expanded[a:new . strpart(l:key, strlen(a:old))] = 1
    else
      let l:expanded[l:key] = 1
    endif
  endfor
  let l:vf.expanded = l:expanded
  let l:vf.cursor_path = a:new
  if get(l:vf, 'copy_path', '') ==# a:old
    let l:vf.copy_path = a:new
  endif
  call s:save_vf(l:buf, l:vf)
endfunction

function! vimfiles#tree#apply_deleted(path) abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  for l:key in keys(get(l:vf, 'expanded', {}))
    if l:key ==# a:path || stridx(l:key, a:path . '/') == 0
      silent! call remove(l:vf.expanded, l:key)
    endif
  endfor
  if get(l:vf, 'cursor_path', '') ==# a:path
    let l:vf.cursor_path = fnamemodify(a:path, ':h')
  endif
  call s:save_vf(l:buf, l:vf)
endfunction

function! vimfiles#tree#is_expanded(path) abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return 0
  endif
  return get(get(s:get_vf(l:buf), 'expanded', {}), a:path, 0)
endfunction

function! vimfiles#tree#sort_state() abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return {'mode': g:vim_files_sort, 'dirs_first': 1, 'reverse': 0}
  endif
  let l:vf = s:get_vf(l:buf)
  return {
        \ 'mode': get(l:vf, 'sort', 'name'),
        \ 'dirs_first': get(l:vf, 'dirs_first', 1),
        \ 'reverse': get(l:vf, 'sort_reverse', 0),
        \ }
endfunction

function! vimfiles#tree#toggle_option(name) abort
  let l:buf = vimfiles#tree#find_buf()
  if l:buf < 0
    return
  endif
  let l:vf = s:get_vf(l:buf)
  if a:name ==# 'dirs_first'
    let l:vf.dirs_first = !get(l:vf, 'dirs_first', 1)
  elseif a:name ==# 'reverse'
    let l:vf.sort_reverse = !get(l:vf, 'sort_reverse', 0)
  else
    return
  endif
  call s:save_vf(l:buf, l:vf)
  call s:render('')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set ts=2 sw=2 sts=2 et fdm=marker:
