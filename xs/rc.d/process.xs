fn latest {
	.d 'List latest START processes for current user'
	.c 'process'
	%view-with-header 1 <{ps auk-start_time -U $USER} latest
}

fn load {
	.d '1/5/15m loadavg; proc counts; last PID'
	.c 'process'
	cat /proc/loadavg
}

fn pcr {
	.d 'Show running average process creation rate'
	.c 'process'
	result %with-terminal
	%only-X
	stq -t pcr -g 20x5 -e xs -c {
		stty -echo
		.ci
		let (dpid = 0; hpid = `{sysctl	-n kernel.pid_max}; \
		ed = <=.%ed; hc = <={%argify `{tput home}}; \
		ul = <=.%au; ue = <=.%aue; lp; pp; dpid; dpidl; \
		pa5; pa10; pa20) {
			%with-quit forever {
				(_ _ _ _ _ lp) = \
					<={~~ <={read </proc/loadavg} \
							*\ *\ *\ */*\ *}
				if {!~ $pp ()} {
					if {$lp :lt $pp} {
						dpid = `($hpid-$pp+$lp)
					} else {
						dpid = `($lp-$pp)
					}
				}
				dpidl = $dpid $dpidl(1 ... 49)
				pa5 = 0.0
				pa10 = 0.0
				pa20 = 0.0
				pa50 = 0.0
				for pd $dpidl(1 ... 5) {
					pa5 = `($pa5+$pd)
					pa10 = `($pa10+$pd)
					pa20 = `($pa20+$pd)
					pa50 = `($pa50+$pd)
				}
				for pd $dpidl(6 ... 10) {
					pa10 = `($pa10+$pd)
					pa20 = `($pa20+$pd)
					pa50 = `($pa50+$pd)
				}
				for pd $dpidl(11 ... 20) {
					pa20 = `($pa20+$pd)
					pa50 = `($pa50+$pd)
				}
				for pd $dpidl(21 ... 50) {
					pa50 = `($pa50+$pd)
				}
				printf '%s%s%swindow'^\t^'avg procs/s%s'^\n \
					^'%3ds'^\t^'%9.1f'^\n \
					^'%3ds'^\t^'%9.1f'^\n \
					^'%3ds'^\t^'%9.1f'^\n \
					^'%3ds'^\t^'%9.1f' \
					$hc $ed $ul $ue \
					5 `($pa5/5) \
					10 `($pa10/10) \
					20 `($pa20/20) \
					50 `($pa50/50)
				pp = $lp
				sleep 1.0
			}
		}
	} &
}

fn pn {
	.d 'Users with active processes'
	.c 'process'
	ps haux|cut -d' ' -f1|sort|uniq
}

fn pof {|*|
	.d 'List process'' open files'
	.a 'pgrep_OPTS'
	.c 'process'
	if {~ $#* 0} {
		.usage pof
	} else {
		let (pl = `{pgrep $*|tr \n ,|head -c-1}) {
			if {~ $pl ()} {
				throw error pof 'no match'
			} else {
				lsof -p $pl | less -iFXS
			}
		}
	}
}

fn ppl {|*|
	.d 'Process parent list'
	.a 'PID'
	.a '(none)  # use shell PID'
	.c 'process'
	let (fmt = '%16.16s %7.7s %7.7s %s'\n; cpid = $*; info) {
		~ $cpid () && cpid = $pid
		printf $fmt USER PPID PID COMM
		while {!~ $cpid 1} {
			info = `{ps -o user=,ppid=,pid=,comm= $cpid}
			printf $fmt $info
			cpid = $info(2)
		}
		true
	}
}

fn prs {|*|
	.d 'Display process info'
	.a '[-f] [prtstat_OPTIONS] NAME'
	.c 'process'
	if {~ $#* 0} {
		.usage prs
	} else {
		let (pgrep_option = -x) {
			{~ $*(1) -f} && {
				pgrep_option = $*(1)
				* = $*(2 ...)
			}
			let (pids = `{pgrep $pgrep_option $*}) {
				if {!~ $pids ()} {
					for pid $pids {
						!~ $#pids 1 && echo '========'
						ps -o command= -p $pid
						echo
						prtstat $pid
					} | less -iFX
				} else {
					echo 'not found'
				}
			}
		}
	}
}

fn pt {|*|
	.d 'ps for user; only processes with terminal'
	.a '[[-fFcyM] USERNAME]'
	.c 'process'
	.r 'pu'
	%view-with-header 1 <{.pu $*|awk '{if ($14 != "?") print}'} pt
}

fn pu {|*|
	.d 'ps for user'
	.a '[[-fFCyM] USERNAME]'
	.c 'process'
	.r 'pt'
	%view-with-header 1 <{.pu $*} pu
}

fn tg {|*|
	.d 'Monitor top %CPU processes exceeding threshold'
	.a '[-d SECONDS] [%CPU_THRESHOLD]  # defaults 1 1.5'
	.c 'process'
	let (thr; d = 1) {
		~ $*(1) -d && { d = $*(2); * = $*(3 ...) }
		thr = $*
		~ $thr () && thr = 1.5
		%with-terminal tg %with-quit {
			watch -n $d -t -p 'echo "tg: %CPU > "'^$thr \
				^'" every "'^$d^'" second"'^<={%plural $d} \
				^'; echo' \
				^'; ps -eo %cpu,%mem,cputime,pid,user,args' \
				^' -k %cpu | awk ''$1=="%CPU" || $1>'$thr^''''
		}
	}
}

fn topc {
	.d 'List top %CPU processes'
	.c 'process'
	.r 'topm topr topt topv'
	ps auxk-%cpu|head -11
}

fn topm {
	.d 'List top %MEM processes'
	.c 'process'
	.r 'topc topr topt topv'
	ps auxk-%mem|head -11
}

fn topr {
	.d 'List top RSS processes'
	.c 'process'
	.r 'topc topm topt topv'
	ps auxk-rss|head -11
}

fn topt {
	.d 'List top TIME processes'
	.c 'process'
	.r 'topc topm topr topv'
	ps auxk-time|head -11
}

fn topv {
	.d 'List top VSZ processes'
	.c 'process'
	.r 'topc topm topr topt'
	ps auk-vsz|head -11
}
