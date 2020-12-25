fn pacer {|*|
	.d 'Hourly stretch reminder'
	.a '[off]'
	.c 'wm'
	let (pspid = ~/.local/run/pacer.pid) {
		if {$#* :ge 1 && !~ $* off} {
			.usage pacer
		} else if {~ $* off} {
			if {access -f $pspid} {
				pkill -g `{cat $pspid}
				echo 'Stopped'
				rm -f $pspid
			}
		} else if {{access -f $pspid} \
				&& {kill -0 `{cat $pspid} >[2]/dev/null}} {
			echo 'Running'
		} else xs -c {
			let (lead = 3) {
				let ( \
				fn-work = { \
					let (initwait; \
					(minute second) = `{date +%M\ %S} \
					) {
						initwait = `(60-$lead-$minute)
						~ $initwait -* 0 && \
							initwait = \
							  `(60+$initwait)
						sleep `(60*$initwait-$second)
					}
				}; \
				fn-check = { \
					let (m = `{date +%M}; t = `(60-$lead)) {
						result <={~ $m $t}
					}
				}; \
				fn-prompt = { \
					%screen-locked || \
					notify 'red|pacer' \
						'Time to stretch!'}; \
				fn-pause = {sleep `(60*$lead)}; \
				fn-go = { \
					%screen-locked || \
					notify 'green|pacer' \
						'Stretch break ends now.'} \
				) {
					echo 'Started'
					work
					while true {
						check && {prompt; pause; go}
						work
					}
				} &
				echo $apid > $pspid
			}
		}
	}
}
