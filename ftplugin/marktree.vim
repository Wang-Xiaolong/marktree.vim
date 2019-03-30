" ftplugin/marktree.vim
" xiaolong.wang@intel.com from Dec.2015

" indent, tab and color
setlocal autoindent
setlocal copyindent
setlocal tabstop=8
setlocal shiftwidth=8
setlocal softtabstop=0
setlocal noexpandtab
setlocal nosmarttab
setlocal textwidth=0
colorscheme marktree

" folding
setlocal foldmethod=expr
setlocal foldexpr=MtFold(v:lnum)
setlocal foldlevel=10

" == Init Function: Get options from MtOption mark ==========================
function! MtSyntaxInit()
	let s:optstr = matchstr(getline(1), '<mt\S*>')
	if s:optstr == ""
		let b:T1LvlCnt = 0
		let b:T2LvlCnt = 0
		let b:MtKeyWordEn = 1
		let b:MtIssueWordEn = 1
		let b:MtTodoWordEn = 1
		return
	endif
	let b:MtExtList = []
	let s:idx = 1
	while 1
		let s:filestr = matchstr(s:optstr, '+\zs\w\+', 0, s:idx)
		if s:filestr == ""
			break
		endif
		let s:filestrfull = g:mtpath . '/syntax/marktree.ext/' . s:filestr . '.vim'
		if filereadable(s:filestrfull)
			execute 'source '.s:filestrfull
			call add(b:MtExtList, s:filestr)
		else
			echo "File not found: " . s:filestrfull
		endif
		let s:idx = s:idx + 1
	endwhile
	let s:optstr = substitute(s:optstr, '+\w\+', '', 'g')
	let b:T1LvlCnt = strlen(substitute(s:optstr, "[^=]", "", "g"))
	let b:T2LvlCnt = strlen(substitute(s:optstr, "[^-]", "", "g"))
	if s:optstr =~ '\^'
		let b:MtKeyWordEn = (s:optstr !~ '*')
		let b:MtIssueWordEn = (s:optstr !~ '?')
		let b:MtTodoWordEn = (s:optstr !~ '!')
	else
		let b:MtKeyWordEn = (s:optstr =~ '*')
		let b:MtIssueWordEn = (s:optstr =~ '?')
		let b:MtTodoWordEn = (s:optstr =~ '!')
	endif
endfunction

let g:mtpath = expand('<sfile>:p:h:h')
call MtSyntaxInit()

function! MtFold(lnum)
	let s:line = getline(a:lnum)

	let s:idx = match(s:line, '\S')
	if s:idx == -1 "empty line
		return '='
	endif	

	let s:synstack = synstack(a:lnum, 1)
	if len(s:synstack) == 0 "Normal
		return b:T1LvlCnt + b:T2LvlCnt + MtIndentLevel(s:line)
	endif
	let s:synroot = synIDattr(s:synstack[0], "name")
	if s:synroot == "MtHead0"
		return 0
	elseif s:synroot == "MtHead1"
		if s:line !~ '^==\+\s\+.\+$' "Not the 1st line
			return '='
		endif "Then, the 1st line
		let s:idx = match(s:line, '[^=]') / 2 "Count of == -> level
		if b:T1LvlCnt < s:idx
			let b:T1LvlCnt = s:idx
		endif
		return b:T1LvlCnt - s:idx
	elseif s:synroot == "MtHead2"
		if s:line !~ '^--\+\s\+.\+$' "Not the 1st line
			return '='
		endif "Then, the 1st line
		let s:idx = match(s:line, '[^-]') / 2 "Count of -- -> level
		if b:T2LvlCnt < s:idx
			let b:T2LvlCnt = s:idx
		endif
		return b:T1LvlCnt + s:idx - 1
	elseif s:synroot == "MtBlockFence"  "tailing mark of a block
		return '='
	elseif s:synroot !~ 'Mt\w\+Block$'  "ordinary line (not start in block)
		return b:T1LvlCnt + b:T2LvlCnt + MtIndentLevel(s:line)
	else "start in block
		" Check if it's the 1st block line
		if len(s:synstack) > 1
			if s:synstack[1] == hlID("MtBlockFence")
				return b:T1LvlCnt + b:T2LvlCnt + 1
			endif
		endif
		" 1st line excluded, now check the last line
		" to judge if current line is 2nd or 3rd+ block line
		try
			let s:last_synstack = synstack(a:lnum - 1, 1)
		catch "if last line is empty, current is 3rd+
			return '='
		endtry
		" if last line is normal, current is 2nd
		if len(s:last_synstack) == 0
			return 'a1'
		endif
		" if last line is not start in the same block, current is 2nd
		if s:last_synstack[0] != s:synstack[0]
			return 'a1'
		endif
		" last line is start in the same block,
		" if last line is 1st block line, current is 2nd
		if len(s:last_synstack) > 1
			if s:last_synstack[1] == hlID("MtBlockFence")
				return 'a1'
			endif
		endif
		" last line is not 1st, so current is 3rd+
		return '='
	endif
endfunction

function! MtIndentLevel(line)
	let s:n_tab_idx = match(a:line, '[^\t]')
	return s:n_tab_idx + (a:line[s:n_tab_idx] == ' ')
endfunction
