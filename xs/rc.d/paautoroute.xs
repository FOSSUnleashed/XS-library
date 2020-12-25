fn paautoroute {|sink client-names|
	.d 'Daemon will route new PulseAudio clients by name to specified sink'
	.a 'SINK CLIENT-NAMES...'
	.c 'system'
	if {~ $client-names ()} {
		.usage paautoroute
	} else {
	let (last = `{date +%s.%N}; shunt = 0; clients; sink-inputs; siid) {
	%with-read-lines <{pactl subscribe \
				|stdbuf -o0 grep 'Event ''new'' on client #' \
				|stdbuf -o0 cut -d\# -f2} {|cid|
		if {$shunt :eq 0 || `{date +%s.%N} :gt `($last+1)} {
			shunt = 1
			last = `{date +%s.%N}
			clients = `` \n {pactl list short clients}
			sink-inputs = `` \n {pactl list \
						short sink-inputs}
			if {~ <={~~ $clients $cid^\tprotocol-native.c\t*} \
							$client-names} {
				(siid _ _) = <={~~ $sink-inputs *\t*\t^$cid \
						^\tprotocol-native.c\t*}
				~ $siid () || {
					pactl move-sink-input $siid $sink
					echo paautoroute \
						sink-input $siid '=>' $sink
				}
			}
		} else {
			# Ignore PA client 'new' events from above code.
			if {$shunt :ge 3} {
				shunt = 0
			} else {
				shunt = `($shunt+1)
			}
		}
	}}}
}
