fn k {|*|
	.d 'Keyboard macros'
	.a '-c  # create'
	.a '-d  # delete'
	.a '-X  # remove all'
	.a '-l  # list'
	.a '1|2|...|9  # confirm and run # macro'
	.a '(none)  # run'
	.c 'system'
	let (kbmdir = ~/.kbmacro) {
		access -d $kbmdir || mkdir $kbmdir
		switch $^* (
		-c {
			if {`{ls $kbmdir|wc -l} :ge 9} {
				throw error k full
			}
			printf 'Create macro> '
			let (cmd = <=read) {
				!~ $cmd () && printf %s $cmd \
						>`{mktemp -p $kbmdir m.XXX}
			}
		}
		-d {local (d = $kbmdir; ml; fl; i = 0) {
			access -f $d/* && for f $d/* {
				ml = $ml `` \n {cat $f}
				fl = $fl $f
			}
			%menu 'Delete macro #' (
				`` \t\n {for mi $ml; f $fl {
					i = `($i+1)
					printf %s\t%s\t%s\t%s\n $i $mi \
						'{rm '^$f \
						^'; echo '''^`` \n { \
							echo $^mi \
							|sed 's/''/''''/g'} \
						^'''}' B
				}}
				. quit {true} B
			)
			echo $df
		}}
		-X {rm -rf $kbmdir}
		-l {access -f $kbmdir/* \
			&& for f $kbmdir/* {cat $f; echo} | nl -w1 -s' '}
		'' {local (d = $kbmdir; ml; i = 0) {
			access -f $d/* && for f $d/* {ml = $ml `` \n {cat $f}}
			if {~ $ml ()} {echo 'no macros'} \
			else %menu 'Run macro #' (
				`` \t\n {for mi $ml {
						i = `($i+1); \
						echo $i^\t^$mi^\t^\{$mi^\} \
									^\t^B
				}}
				. quit {true} B
			)
		}}
		{if {~ $* 1 2 3 4 5 6 7 8 9} {
			let (i = 1; c) {{escape {|fn-break|
				for f $kbmdir/* {
					if {~ $i $*} {
						c = `` \n {cat $f}
						if {%confirm n $c} {
							xs -c $c
						}
						break
					}
					i = `($i+1)
				}
			}}}
		} else {.usage k}}
		)
	}
}
