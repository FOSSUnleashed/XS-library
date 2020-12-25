# Clean the $history file by removing:
#  a) leading and trailing blanks
#  b) one-word commands
#  c) commands that match specific patterns
#  d) consecutive repetitions of commands
#  e) if the remaining file has at least 1,500 but fewer than 3,000 lines,
#     remove duplicates from the first 2/3 of the file; if there are at
#     least 3,000 lines, remove duplicates from all but the last 500 lines.
#  f) if, after step (e) the remaining file has more than 3,000 lines,
#     delete all but the last 3,000 lines.

fn histclean {
	.d 'Clean the xs $history file'
	.c 'xs'
	fn clean {|hstfile tmpfile|
		let (oline; drop) {
		%with-read-lines $hstfile {|line|
			oline = `` \n {echo $line | sed 's/^ \+//;s/ \+$//'}
			drop = <={
				{!~ $oline *\ *} \
				|| {~ $oline rm\ * cp\ * mv\ * la\ * \
					ll\ * ls\ * lt\ * history\ * \
					youtube-dl\ * mpv\ * mpvl\ * \
					help\ * luca\ *}
			}
			result $drop || {echo $oline}
		} >$tmpfile
		}
	}
	let ( \
	hstfile; lc_start; tmpfile; lc_pass1; prefix; lc_pass2; lc_finish \
	) {
	if {!~ $history () && access -f $history} {
		hstfile = $history
		history -n
		lc_start = `{cat $hstfile | wc -l}
		tmpfile = `mktemp
		%with-throbber 'Cleaning... ' {
			%split-xform-join clean 1 $hstfile `mktemp $tmpfile
		}
		lc_pass1 = `{cat $tmpfile | wc -l}
		if {$lc_pass1 :ge 1500} {
			if {$lc_pass1 :ge 3000} {
				len0 = `($lc_pass1-500)
			} else {
				len0 = `($lc_pass1*2/3)
			}
			prefix = /tmp/$pid^_
			split -l $len0 -d -a 1 $tmpfile $prefix
			cat <{cat $prefix^0 | sort | uniq | shuf} $prefix^1 > $tmpfile
			rm $prefix^?
			lc_pass2 = `{cat $tmpfile | wc -l}
			if {$lc_pass2 :gt 3000} {
				tail -n 3000 $tmpfile > $prefix^1
				cat $prefix^1 > $tmpfile
				rm $prefix^?
			}
		}
		cp $tmpfile $hstfile
		rm $tmpfile
		lc_finish = `{cat $hstfile | wc -l}
		printf \r'Removed %d line%s; %d remain'\n \
				`($lc_start - $lc_finish) \
				<={if {~ `($lc_start-$lc_finish) 1} {
					result ''
				} else {
					result s}} \
				`{cat $hstfile | wc -l}
		history -y
	}
	} #let
	fn clean
}
