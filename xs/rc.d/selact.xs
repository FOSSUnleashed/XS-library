fn selact {
	.d 'Act upon selected text'
	.c 'system'
	%with^-terminal selact {
		%menu 'Apply to selected text:' (
		a Amazon {amazon `xsel} B
		d Dictionary {dict `xsel} B
		g Google {google `xsel} B
		h Hangout {hangout `xsel} B
		i dnf\ info {dnf -C info `xsel} B
		k Wikipedia {wikipedia `xsel} B
		o Open {open `` \n xsel &} B
		s Scholar {scholar `xsel} B
		w Web {web `xsel} B
		x Searx {searx `xsel} B
		. cancel {true} B
		)
	}
}