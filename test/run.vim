" Test suite for vim-files.  Run with:
"   vim -Nu NONE -es -S test/run.vim

scriptencoding utf-8
set nocompatible
set noswapfile
set hidden
set columns=120
set lines=50

let s:root = expand('<sfile>:p:h:h')
execute 'set rtp^=' . fnameescape(s:root)
execute 'set rtp+=' . fnameescape(expand('~/.vim/plugged/vim-devicons'))
filetype plugin indent on
syntax on
let g:vim_files_preview_delay = 0
runtime! plugin/vim-files.vim

let s:base = vimfiles#fs#normalize(tempname() . '-vim-files-test')
call mkdir(s:base . '/dirA/sub', 'p')
call mkdir(s:base . '/dirB', 'p')
call mkdir(s:base . '/with space', 'p')
call writefile(['alpha'], s:base . '/a.txt')
call writefile(['hidden'], s:base . '/.hidden')
call writefile(['ds'], s:base . '/.DS_Store')
call writefile(['python'], s:base . '/dirA/b.py')
call writefile(['js'], s:base . '/dirA/sub/c.js')
call writefile(['spaced'], s:base . '/with space/file.txt')

function! s:names() abort
  return map(copy(get(b:, 'vim_files_state', {}).nodes), 'v:val.name')
endfunction

function! s:line_index(pattern) abort
  let l:i = 0
  for l:line in getline(1, '$')
    let l:i += 1
    if l:line =~# a:pattern
      return l:i
    endif
  endfor
  return 0
endfunction

call assert_equal(s:base . '/dirA', vimfiles#fs#normalize(s:base . '/dirA/'))
call assert_equal('dirA/b.py', vimfiles#fs#relpath(s:base . '/dirA/b.py', s:base))
call assert_true(vimfiles#fs#is_under(s:base . '/dirA/b.py', s:base))
call assert_false(vimfiles#fs#is_under('/tmp', s:base))
call assert_equal('1 KB', vimfiles#fs#format_size(1024))
call assert_equal('1.5 MB', vimfiles#fs#format_size(1024 * 1024 + 512 * 1024))
call assert_equal('python', vimfiles#fs#filetype(s:base . '/dirA/b.py'))
call assert_equal('javascript', vimfiles#fs#filetype(s:base . '/dirA/sub/c.js'))

let s:new = vimfiles#fs#create(s:base, 'dirA/new.txt')
call assert_true(filereadable(s:new))
let s:newdir = vimfiles#fs#create(s:base, 'made/nested/')
call assert_true(isdirectory(s:newdir))
let s:renamed = vimfiles#fs#rename(s:new, 'renamed.txt')
call assert_true(filereadable(s:renamed))
call assert_false(filereadable(s:new))
let s:copied = vimfiles#fs#copy(s:renamed, s:base . '/dirB')
call assert_true(filereadable(s:copied))
let s:copied2 = vimfiles#fs#copy(s:renamed, s:base . '/dirB')
call assert_notequal(s:copied, s:copied2)
call assert_true(filereadable(s:copied2))
let s:dircopy = vimfiles#fs#copy(s:base . '/dirA', s:base . '/dirB')
call assert_true(isdirectory(s:dircopy . '/sub'))
call assert_true(filereadable(s:dircopy . '/sub/c.js'))
call vimfiles#fs#delete(s:copied)
call vimfiles#fs#delete(s:copied2)
call vimfiles#fs#delete(s:dircopy)
call vimfiles#fs#delete(s:newdir)
call vimfiles#fs#delete(fnamemodify(s:newdir, ':h'))
call assert_true(empty(getftype(s:copied)))
call assert_true(empty(getftype(s:dircopy)))

let s:git_ok = executable('git')
if s:git_ok
  call system('git -C ' . shellescape(s:base) . ' init -q')
  call system('git -C ' . shellescape(s:base) . ' config user.email test@example.com')
  call system('git -C ' . shellescape(s:base) . ' config user.name Test')
  call system('git -C ' . shellescape(s:base) . ' config commit.gpgsign false')
  call system('git -C ' . shellescape(s:base) . ' add a.txt dirA/b.py dirA/sub/c.js')
  call system('git -C ' . shellescape(s:base) . ' commit -qm init')
  call writefile(['alpha changed'], s:base . '/a.txt')
  call writefile(['python changed'], s:base . '/dirA/b.py')
  call writefile(['new'], s:base . '/untracked.txt')
  let g:vim_files_show_git = 1
  let s:git = vimfiles#git#load(s:base)
  call assert_true(s:git.is_repo)
  call assert_notequal('', s:git.branch)
  call assert_equal('modified', get(s:git.files, s:base . '/a.txt', ''))
  call assert_equal('untracked', get(s:git.files, s:base . '/untracked.txt', ''))
  call assert_equal('modified', get(s:git.dirs, s:base, ''))
  let s:subgit = vimfiles#git#load(s:base . '/dirA')
  call assert_true(s:subgit.is_repo)
  call assert_false(has_key(s:subgit.files, s:base . '/a.txt'))
  call assert_true(has_key(s:subgit.files, s:base . '/dirA/b.py')
        \ || has_key(s:subgit.files, s:base . '/dirA/sub/c.js'))
else
  call add(v:errors, 'git not found; git tests skipped')
endif

VimFiles
call vimfiles#tree#set_root(s:base)
call assert_equal('[vim-files]', fnamemodify(bufname('%'), ':t'))
call assert_equal(s:base, vimfiles#tree#root())
call assert_true(vimfiles#tree#is_open())
call assert_true(vimfiles#tree#is_open_here())

let s:names = s:names()
call assert_equal('dirA', s:names[1])
call assert_equal('dirB', s:names[2])
call assert_equal('with space', s:names[3])
call assert_equal('a.txt', s:names[4])
call assert_false(index(s:names, '.hidden') >= 0)

let s:lnum = s:line_index('dirA/')
call cursor(s:lnum, 1)
call vimfiles#ui#action('open')
call assert_true(vimfiles#tree#is_expanded(s:base . '/dirA'))
call assert_true(s:line_index('b\.py') > 0)
call cursor(s:line_index('dirA/'), 1)
call vimfiles#ui#action('collapse_or_parent')
call assert_false(vimfiles#tree#is_expanded(s:base . '/dirA'))
call assert_equal(0, s:line_index('b\.py'))

call assert_equal([], g:vim_files_ignore)
call vimfiles#tree#toggle_hidden()
call assert_true(index(s:names(), '.hidden') >= 0)
call assert_true(index(s:names(), '.DS_Store') >= 0)
if s:git_ok
  call assert_true(index(s:names(), '.git') >= 0)
endif
call vimfiles#tree#toggle_hidden()
call assert_true(index(s:names(), '.hidden') < 0)
call assert_true(index(s:names(), '.DS_Store') < 0)
if s:git_ok
  call assert_true(index(s:names(), '.git') < 0)
endif

call vimfiles#tree#set_sort('extension')
call assert_equal('extension', vimfiles#tree#sort_mode())
call vimfiles#tree#set_sort('size')
call assert_equal('size', vimfiles#tree#sort_mode())
call vimfiles#tree#set_sort('name')
call assert_equal('name', vimfiles#tree#sort_mode())
call vimfiles#tree#toggle_option('dirs_first')
call assert_equal(0, vimfiles#tree#sort_state().dirs_first)
call vimfiles#tree#toggle_option('dirs_first')
call assert_equal(1, vimfiles#tree#sort_state().dirs_first)

if s:git_ok
  call vimfiles#tree#refresh({'git': 1})
  call assert_true(match(join(getline(1, '$'), "\n"), 'a\.txt.*✗') >= 0)
  call assert_true(match(join(getline(1, '$'), "\n"), 'untracked\.txt.*★') >= 0)
endif

let s:vf = getbufvar(vimfiles#tree#find_buf(), 'vim_files_state', {})
call assert_equal(0, get(s:vf, 'auto_preview', -1))
call assert_equal(1, g:vim_files_preview_fill)
call assert_match('toggle_auto_preview', maparg('p', 'n'))
call assert_match('preview', maparg('<C-p>', 'n'))
call assert_match('scroll_h', maparg('L', 'n'))
call assert_match('scroll_h', maparg('H', 'n'))
call assert_match('preview#scroll', maparg('J', 'n'))
let s:fileline = s:line_index('a\.txt')
call cursor(s:fileline, 1)
call vimfiles#tree#on_cursor_moved()
call assert_false(vimfiles#preview#is_open())
call vimfiles#tree#toggle_auto_preview()
call assert_equal(1, get(getbufvar(vimfiles#tree#find_buf(), 'vim_files_state', {}), 'auto_preview', -1))
call cursor(s:fileline, 1)
call vimfiles#tree#on_cursor_moved()
call assert_true(vimfiles#preview#is_open())
call assert_equal(s:base . '/a.txt', vimfiles#preview#path())
call vimfiles#preview#scroll(1)
let s:pid = get(popup_list(), 0, -1)
call assert_true(s:pid > 0)
call assert_equal('alpha changed', get(getbufline(winbufnr(s:pid), 1, 1), 0, ''))
call assert_equal('text', getbufvar(winbufnr(s:pid), '&filetype'))
call assert_equal('a.txt', fnamemodify(vimfiles#preview#path(), ':t'))
call vimfiles#preview#close()
call assert_false(vimfiles#preview#is_open())
call vimfiles#preview#show(s:base . '/a.txt', 1)
call assert_true(vimfiles#preview#is_open())
call vimfiles#preview#toggle(s:base . '/a.txt')
call assert_false(vimfiles#preview#is_open())

call writefile([repeat('0123456789', 30)], s:base . '/longline.txt')
call vimfiles#preview#show(s:base . '/longline.txt', 1)
let s:pid = get(popup_list(), 0, -1)
call assert_true(get(getbufline(winbufnr(s:pid), 1, 1), 0, '') =~# '^0123456789')
call vimfiles#preview#scroll_h(3)
call assert_true(get(getbufline(winbufnr(s:pid), 1, 1), 0, '') =~# '^3456789')
call vimfiles#preview#scroll_h(-3)
call assert_true(get(getbufline(winbufnr(s:pid), 1, 1), 0, '') =~# '^0123456789')
call vimfiles#preview#close()

call vimfiles#preview#show(s:base . '/a.txt', 1)
let s:pid = get(popup_list(), 0, -1)
call cursor(s:line_index('dirA/'), 1)
doautocmd CursorMoved
call assert_true(vimfiles#preview#is_open())
call assert_equal(s:base . '/dirA', vimfiles#preview#path())
call assert_equal(s:pid, get(popup_list(), 0, -1))
call assert_true(match(join(getbufline(winbufnr(s:pid), 1, '$'), "\n"), 'sub/') >= 0)
call cursor(s:line_index('a\.txt'), 1)
doautocmd CursorMoved
call assert_true(vimfiles#preview#is_open())
call assert_equal(s:base . '/a.txt', vimfiles#preview#path())
call assert_equal(s:pid, get(popup_list(), 0, -1))

call vimfiles#ui#run('details', s:base . '/a.txt', 0)
call assert_notequal([], popup_list())
call vimfiles#ui#escape()
call assert_equal([], popup_list())
call vimfiles#ui#menu()
call assert_notequal([], popup_list())
call popup_clear()
call vimfiles#ui#run('sort_menu', s:base . '/a.txt', 0)
call assert_notequal([], popup_list())
call popup_clear()
call vimfiles#ui#run('copy_menu', s:base . '/a.txt', 0)
call assert_notequal([], popup_list())
call popup_clear()
call vimfiles#ui#help()
call assert_notequal([], popup_list())
call vimfiles#ui#escape()

call vimfiles#tree#open_file(s:base . '/dirA/sub/c.js', 'edit')
call assert_equal(s:base . '/dirA/sub/c.js', expand('%:p'))
call vimfiles#find()
call assert_equal('[vim-files]', fnamemodify(bufname('%'), ':t'))
call assert_equal(s:base . '/dirA/sub/c.js', vimfiles#tree#current_node().path)

call assert_true(index(map(getmatches(), 'v:val.group'), 'VimFilesCurrentFile') >= 0)

call vimfiles#tree#close()
VimFiles
call vimfiles#tree#close()
execute 'VimFiles ' . fnameescape(s:base . '/dirA/b.py')
call assert_equal(s:base . '/dirA', vimfiles#tree#root())
call assert_equal(s:base . '/dirA/b.py', vimfiles#tree#current_node().path)

call vimfiles#tree#close()
execute 'edit ' . fnameescape(s:base . '/dirA/sub/c.js')
call vimfiles#find()
call assert_true(vimfiles#tree#is_open_here())
call assert_equal(s:base . '/dirA/sub/c.js', vimfiles#tree#current_node().path)
call vimfiles#tree#set_root(s:base)

execute 'VimFiles ' . fnameescape(s:base . '/dirA')
call assert_equal(s:base . '/dirA', vimfiles#tree#root())
call assert_true(match(join(getline(1, '$'), "\n"), 'dirA/') >= 0)

call vimfiles#tree#open(s:base . '/with space')
call assert_equal(s:base . '/with space', vimfiles#tree#root())
call vimfiles#tree#set_root(s:base)

call assert_match('open_keep_focus', maparg('go', 'n'))
call vimfiles#tree#refresh()
let s:lline = s:line_index('longline\.txt')
call assert_true(s:lline > 0)
call cursor(s:lline, 1)
call vimfiles#ui#action('open_keep_focus')
call assert_equal('[vim-files]', fnamemodify(bufname('%'), ':t'))
call assert_true(!empty(win_findbuf(bufnr(s:base . '/longline.txt'))))

call vimfiles#tree#open_file(s:base . '/dirA/b.py', 'tab')
call assert_equal(s:base . '/dirA/b.py', expand('%:p'))
tabclose
call vimfiles#tree#open_file(s:base . '/dirA/b.py', 'vsplit')
call assert_equal(s:base . '/dirA/b.py', expand('%:p'))
let s:treewin = vimfiles#tree#win()
if s:treewin > 0
  call win_gotoid(s:treewin)
endif
call vimfiles#tree#open_file(s:base . '/dirA/b.py', 'split')
call assert_equal(s:base . '/dirA/b.py', expand('%:p'))

call vimfiles#tree#open_file(s:base . '/a.txt', 'edit')
call writefile(['x'], s:base . '/autorefresh.txt')
call vimfiles#on_write(s:base . '/autorefresh.txt')
let s:treebuf = vimfiles#tree#find_buf()
call assert_true(match(join(getbufline(s:treebuf, 1, '$'), "\n"), 'autorefresh\.txt') >= 0)

call vimfiles#tree#close()
call assert_false(vimfiles#tree#is_open_here())
call vimfiles#toggle()
call assert_true(vimfiles#tree#is_open_here())
call assert_equal(s:base, vimfiles#tree#root())
call vimfiles#tree#close()
call assert_false(vimfiles#tree#is_open_here())

call vimfiles#fs#delete(s:base)
if empty(v:errors)
  call writefile(['PASS'], s:root . '/test/result.txt')
  qall!
else
  call writefile(v:errors, s:root . '/test/result.txt')
  cquit
endif
