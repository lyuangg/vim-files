" vim-files: filesystem helpers

let s:save_cpo = &cpo
set cpo&vim

function! vimfiles#fs#normalize(path) abort
  if empty(a:path)
    return ''
  endif
  let l:path = expand(a:path)
  if empty(l:path)
    return ''
  endif
  let l:path = fnamemodify(l:path, ':p')
  if l:path ==# '/'
    return l:path
  endif
  let l:path = substitute(l:path, '[/\\]\+$', '', '')
  if l:path =~# '^[A-Za-z]:$'
    let l:path .= '/'
  endif
  return l:path
endfunction

function! vimfiles#fs#strip_slash(path) abort
  if a:path ==# '/'
    return a:path
  endif
  let l:path = substitute(a:path, '[/\\]\+$', '', '')
  if l:path =~# '^[A-Za-z]:$'
    let l:path .= '/'
  endif
  return l:path
endfunction

function! vimfiles#fs#join(dir, name) abort
  if a:dir ==# '/'
    return '/' . a:name
  endif
  let l:dir = vimfiles#fs#strip_slash(a:dir)
  if l:dir =~# '/$'
    return l:dir . a:name
  endif
  return l:dir . '/' . a:name
endfunction

function! vimfiles#fs#basename(path) abort
  return fnamemodify(vimfiles#fs#strip_slash(a:path), ':t')
endfunction

function! vimfiles#fs#relpath(path, root) abort
  let l:path = vimfiles#fs#normalize(a:path)
  let l:root = vimfiles#fs#normalize(a:root)
  if empty(l:path) || empty(l:root)
    return a:path
  endif
  if l:path ==# l:root
    return '.'
  endif
  let l:prefix = l:root =~# '/$' ? l:root : l:root . '/'
  if stridx(l:path, l:prefix) == 0
    return strpart(l:path, strlen(l:prefix))
  endif
  return l:path
endfunction

function! vimfiles#fs#is_under(path, root) abort
  let l:path = vimfiles#fs#normalize(a:path)
  let l:root = vimfiles#fs#normalize(a:root)
  if empty(l:path) || empty(l:root)
    return 0
  endif
  if l:path ==# l:root
    return 1
  endif
  let l:prefix = l:root =~# '/$' ? l:root : l:root . '/'
  return stridx(l:path, l:prefix) == 0
endfunction

function! vimfiles#fs#format_size(size) abort
  if a:size < 0
    return 'unknown'
  endif
  if a:size < 1024
    return a:size . ' B'
  elseif a:size < 1024 * 1024
    return substitute(printf('%.1f KB', a:size / 1024.0), '\.0 ', ' ', '')
  elseif a:size < 1024 * 1024 * 1024
    return substitute(printf('%.1f MB', a:size / (1024.0 * 1024.0)), '\.0 ', ' ', '')
  endif
  return substitute(printf('%.1f GB', a:size / (1024.0 * 1024.0 * 1024.0)), '\.0 ', ' ', '')
endfunction

function! vimfiles#fs#pretty_time(time) abort
  if a:time < 0
    return 'unknown'
  endif
  return strftime('%Y-%m-%d %H:%M:%S', a:time)
endfunction

let s:ft_by_ext = {
      \ 'vim': 'vim', 'py': 'python', 'pyi': 'python', 'js': 'javascript',
      \ 'mjs': 'javascript', 'cjs': 'javascript', 'jsx': 'javascriptreact',
      \ 'ts': 'typescript', 'tsx': 'typescriptreact', 'json': 'json',
      \ 'jsonc': 'jsonc', 'md': 'markdown', 'markdown': 'markdown',
      \ 'go': 'go', 'rs': 'rust', 'c': 'c', 'h': 'c', 'cc': 'cpp',
      \ 'cpp': 'cpp', 'cxx': 'cpp', 'hpp': 'cpp', 'hh': 'cpp', 'hxx': 'cpp',
      \ 'm': 'objc', 'mm': 'objcpp', 'sh': 'sh', 'bash': 'bash', 'zsh': 'zsh',
      \ 'fish': 'fish', 'rb': 'ruby', 'php': 'php', 'html': 'html',
      \ 'htm': 'html', 'css': 'css', 'scss': 'scss', 'sass': 'sass',
      \ 'less': 'less', 'vue': 'vue', 'svelte': 'svelte', 'yaml': 'yaml',
      \ 'yml': 'yaml', 'toml': 'toml', 'ini': 'dosini', 'conf': 'conf',
      \ 'sql': 'sql', 'java': 'java', 'kt': 'kotlin', 'kts': 'kotlin',
      \ 'swift': 'swift', 'lua': 'lua', 'r': 'r', 'pl': 'perl', 'pm': 'perl',
      \ 'ex': 'elixir', 'exs': 'elixir', 'erl': 'erlang', 'hrl': 'erlang',
      \ 'hs': 'haskell', 'clj': 'clojure', 'cljs': 'clojure', 'scala': 'scala',
      \ 'proto': 'proto', 'graphql': 'graphql', 'gql': 'graphql',
      \ 'xml': 'xml', 'xhtml': 'xhtml', 'diff': 'diff', 'patch': 'diff',
      \ 'dockerfile': 'dockerfile', 'make': 'make', 'cmake': 'cmake',
      \ 'txt': 'text', 'log': 'text', 'csv': 'csv', 'tsv': 'tsv',
      \ }

let s:ft_by_name = {
      \ 'makefile': 'make', 'gnumakefile': 'make', 'dockerfile': 'dockerfile',
      \ 'cmakelists.txt': 'cmake', 'gemfile': 'ruby', 'rakefile': 'ruby',
      \ 'vagrantfile': 'ruby', 'jenkinsfile': 'groovy', 'go.mod': 'gomod',
      \ 'go.sum': 'gosum', '.gitignore': 'gitignore', '.gitconfig': 'gitconfig',
      \ '.vimrc': 'vim', '_vimrc': 'vim', '.gvimrc': 'vim', 'gvimrc': 'vim',
      \ '.zshrc': 'zsh', '.bashrc': 'sh', '.profile': 'sh',
      \ 'package.json': 'json', 'tsconfig.json': 'jsonc',
      \ 'requirements.txt': 'text', 'setup.py': 'python', 'pyproject.toml': 'toml',
      \ }

function! vimfiles#fs#filetype(path) abort
  let l:name = tolower(fnamemodify(a:path, ':t'))
  let l:ext = tolower(fnamemodify(a:path, ':e'))

  let l:bufnr = bufnr(a:path)
  if l:bufnr != -1 && bufloaded(l:bufnr)
    let l:ft = getbufvar(l:bufnr, '&filetype')
    if !empty(l:ft)
      return l:ft
    endif
  endif

  if has_key(s:ft_by_name, l:name)
    return s:ft_by_name[l:name]
  endif
  if has_key(s:ft_by_ext, l:ext)
    return s:ft_by_ext[l:ext]
  endif
  if empty(l:ext)
    return ''
  endif
  let l:fts = getcompletion(l:ext, 'filetype')
  if index(l:fts, l:ext) >= 0
    return l:ext
  endif
  return ''
endfunction

let s:binary_exts = {
      \ 'png': 1, 'jpg': 1, 'jpeg': 1, 'gif': 1, 'bmp': 1, 'ico': 1,
      \ 'webp': 1, 'tiff': 1, 'psd': 1, 'pdf': 1, 'zip': 1, 'gz': 1,
      \ 'bz2': 1, 'xz': 1, '7z': 1, 'rar': 1, 'tar': 1, 'tgz': 1,
      \ 'mp3': 1, 'mp4': 1, 'm4a': 1, 'wav': 1, 'flac': 1, 'ogg': 1,
      \ 'mov': 1, 'avi': 1, 'mkv': 1, 'webm': 1, 'ttf': 1, 'otf': 1,
      \ 'woff': 1, 'woff2': 1, 'eot': 1, 'so': 1, 'dylib': 1, 'a': 1,
      \ 'o': 1, 'obj': 1, 'class': 1, 'jar': 1, 'war': 1, 'exe': 1,
      \ 'dll': 1, 'bin': 1, 'dat': 1, 'db': 1, 'sqlite': 1, 'sqlite3': 1,
      \ 'pyc': 1, 'pyo': 1, 'wasm': 1, 'doc': 1, 'docx': 1, 'xls': 1,
      \ 'xlsx': 1, 'ppt': 1, 'pptx': 1, 'epub': 1, 'dmg': 1, 'iso': 1,
      \ }

function! vimfiles#fs#is_regular(path) abort
  let l:type = getftype(a:path)
  if l:type ==# 'file'
    return 1
  endif
  if l:type ==# 'link'
    return getftype(resolve(a:path)) ==# 'file'
  endif
  return 0
endfunction

function! vimfiles#fs#is_binary(path) abort
  let l:ext = tolower(fnamemodify(a:path, ':e'))
  if has_key(s:binary_exts, l:ext)
    return 1
  endif
  if exists('*readblob') && exists('*blob2list')
    try
      let l:bytes = blob2list(readblob(a:path, 0, 1024))
    catch
      return 0
    endtry
    return index(l:bytes, 0) >= 0
  endif
  return 0
endfunction

function! vimfiles#fs#create(base, name) abort
  let l:name = a:name
  if empty(l:name)
    throw 'vim-files: empty name'
  endif
  let l:is_dir = l:name =~# '[/\\]$'
  let l:name = substitute(l:name, '^\s*', '', '')
  let l:name = substitute(l:name, '\s*$', '', '')
  if empty(l:name)
    throw 'vim-files: empty name'
  endif
  let l:name = expand(l:name)
  let l:path = l:name =~# '^/' ? l:name : vimfiles#fs#join(a:base, l:name)
  let l:path = vimfiles#fs#strip_slash(fnamemodify(l:path, ':p'))
  if !empty(getftype(l:path))
    throw 'vim-files: already exists: ' . l:path
  endif

  if l:is_dir
    if !mkdir(l:path, 'p') && !isdirectory(l:path)
      throw 'vim-files: could not create directory: ' . l:path
    endif
  else
    let l:parent = fnamemodify(l:path, ':h')
    if !isdirectory(l:parent) && !mkdir(l:parent, 'p')
      throw 'vim-files: could not create parent directory: ' . l:parent
    endif
    if writefile([], l:path, 'b') != 0
      throw 'vim-files: could not create file: ' . l:path
    endif
  endif
  return l:path
endfunction

function! vimfiles#fs#rename(path, newname) abort
  let l:src = vimfiles#fs#normalize(a:path)
  let l:newname = substitute(a:newname, '^\s*', '', '')
  let l:newname = substitute(l:newname, '\s*$', '', '')
  if empty(l:newname)
    throw 'vim-files: empty name'
  endif
  let l:newname = expand(l:newname)
  let l:dest = l:newname =~# '^/' ? l:newname : vimfiles#fs#join(fnamemodify(l:src, ':h'), l:newname)
  let l:dest = vimfiles#fs#strip_slash(fnamemodify(l:dest, ':p'))
  if l:dest ==# l:src
    return l:dest
  endif
  if !empty(getftype(l:dest))
    throw 'vim-files: already exists: ' . l:dest
  endif
  let l:parent = fnamemodify(l:dest, ':h')
  if !isdirectory(l:parent) && !mkdir(l:parent, 'p')
    throw 'vim-files: could not create parent directory: ' . l:parent
  endif
  if rename(l:src, l:dest) != 0
    throw 'vim-files: could not rename: ' . l:src
  endif
  return l:dest
endfunction

function! vimfiles#fs#delete(path) abort
  let l:path = vimfiles#fs#normalize(a:path)
  let l:type = getftype(l:path)
  if empty(l:type)
    throw 'vim-files: no such file: ' . l:path
  endif
  if l:type ==# 'dir'
    if delete(l:path, 'rf') != 0
      throw 'vim-files: could not delete directory: ' . l:path
    endif
  else
    if delete(l:path) != 0
      throw 'vim-files: could not delete file: ' . l:path
    endif
  endif
endfunction

function! vimfiles#fs#unique_copy_name(dir, name) abort
  let l:base = fnamemodify(a:name, ':r')
  let l:ext = fnamemodify(a:name, ':e')
  let l:suffix = empty(l:ext) ? '' : '.' . l:ext
  let l:candidate = a:name
  let l:i = 1
  while !empty(getftype(vimfiles#fs#join(a:dir, l:candidate)))
    if l:i == 1
      let l:candidate = l:base . ' copy' . l:suffix
    else
      let l:candidate = l:base . ' copy ' . l:i . l:suffix
    endif
    let l:i += 1
    if l:i > 1000
      throw 'vim-files: could not find a free copy name'
    endif
  endwhile
  return l:candidate
endfunction

function! vimfiles#fs#copy(src, dest_dir) abort
  let l:src = vimfiles#fs#normalize(a:src)
  let l:dest_dir = vimfiles#fs#normalize(a:dest_dir)
  if empty(getftype(l:src))
    throw 'vim-files: no such file: ' . l:src
  endif
  if !isdirectory(l:dest_dir)
    throw 'vim-files: not a directory: ' . l:dest_dir
  endif
  let l:srcprefix = l:src =~# '/$' ? l:src : l:src . '/'
  if isdirectory(l:src) && (l:dest_dir ==# l:src || stridx(l:dest_dir, l:srcprefix) == 0)
    throw 'vim-files: cannot copy a directory into itself'
  endif

  let l:name = vimfiles#fs#unique_copy_name(l:dest_dir, fnamemodify(l:src, ':t'))
  let l:dest = vimfiles#fs#join(l:dest_dir, l:name)
  call s:copy_recursive(l:src, l:dest)
  return l:dest
endfunction

function! s:copy_recursive(src, dest) abort
  if has('unix')
    let l:out = system('cp -R ' . shellescape(a:src) . ' ' . shellescape(a:dest) . ' 2>&1')
    if v:shell_error != 0
      throw 'vim-files: copy failed: ' . substitute(l:out, '\n', ' ', 'g')
    endif
    return
  endif

  if isdirectory(a:src)
    if !mkdir(a:dest, 'p') && !isdirectory(a:dest)
      throw 'vim-files: could not create directory: ' . a:dest
    endif
    for l:name in readdir(a:src)
      call s:copy_recursive(vimfiles#fs#join(a:src, l:name), vimfiles#fs#join(a:dest, l:name))
    endfor
  else
    if writefile(readfile(a:src, 'b'), a:dest, 'b') != 0
      throw 'vim-files: could not copy file: ' . a:src
    endif
  endif
endfunction

function! vimfiles#fs#info(path) abort
  let l:path = vimfiles#fs#normalize(a:path)
  let l:type = getftype(l:path)
  let l:info = {
        \ 'path': l:path,
        \ 'name': fnamemodify(l:path, ':t'),
        \ 'type': empty(l:type) ? 'unknown' : l:type,
        \ 'is_dir': isdirectory(l:path),
        \ 'size': getfsize(l:path),
        \ 'mtime': getftime(l:path),
        \ 'perm': getfperm(l:path),
        \ 'link': l:type ==# 'link',
        \ 'target': '',
        \ 'lines': -1,
        \ 'entries': -1,
        \ }
  if l:info.name ==# ''
    let l:info.name = l:path
  endif

  if l:info.link
    let l:info.target = resolve(l:path)
  endif

  if l:info.is_dir
    try
      let l:info.entries = len(readdir(l:path))
    catch
      let l:info.entries = -1
    endtry
  elseif vimfiles#fs#is_regular(l:path) && l:info.size >= 0
        \ && l:info.size <= 2 * 1024 * 1024
        \ && !vimfiles#fs#is_binary(l:path)
    try
      let l:lines = readfile(l:path, '', 10001)
      let l:info.lines = len(l:lines)
      if l:info.lines > 10000
        let l:info.lines = 10000
        let l:info.lines_truncated = 1
      endif
    catch
    endtry
  endif
  return l:info
endfunction

function! vimfiles#fs#yank(text) abort
  let l:copied = 0
  if has('clipboard')
    try
      call setreg('+', a:text)
      let l:copied = 1
    catch
    endtry
  endif
  if !l:copied && has('macunix') && executable('pbcopy')
    call system('pbcopy', a:text)
    let l:copied = v:shell_error == 0
  endif
  if !l:copied
    call setreg('"', a:text)
  endif
  return l:copied
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set ts=2 sw=2 sts=2 et fdm=marker:
