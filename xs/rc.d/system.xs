fn addr {|*|
	.d 'Show IP addresses'
	.a '[-r]  # resolve'
	.c 'system'
	if {{!~ $#* 0} && {!~ $* -r}} {
		.usage addr
	} else {
		%with-terminal addr {
			ip $* -br address | grep -v DOWN \
			| sed 's/^\([^ ]\+ \+\).\{8\}\( \+[^ ]\+\)' \
				^'\(\( [^ ]\+\)\+\)/\1\2\n\t\3/' \
			| awk -f <{cat << 'EOF'
BEGIN { pf = 0; }
/^\t/ {
	n = split($0, addrs, / /)
	for (i = 2; i < n; ++i) {
		if (addrs[i] == "peer") {pf = 1; continue;}
		if (pf) {
			print "\t\t\tpeer " addrs[i]
			pf = 0
		} else {
			print "\t\t\t" addrs[i]
		}
	}
}
/^[^\t]/ {
	print
}
EOF
				}
			| %wt-pager
		}
	}
}

fn awc {|*|
	.d 'Keep system awake while lid closed'
	.a 'HOURS # default: 8'
	.c 'system'
	if %is-mobile {
		let (msg = 'Remain awake with lid closed for specified ' \
			^'period or until exited (press q).'; h) {
			if {grep -q $^msg <{systemd-inhibit --list}} {
				echo 'already active'
			} else {
				if {~ $#* 0} {h = 8} else {h = $*}
				if {!~ $h [0-9] [1-9][0-9] [1-9][0-9][0-9]} {
					throw error awc 'invalid duration'
				}
				echo $msg
				echo Active for $h hour^<={%plural $h}^\; \
					ends `` \n {date -d $h^' hours'}^.
				unwind-protect {
					%without-echo %with-quit \
					systemd-inhibit \
						--what=handle-lid-switch \
						--why=$msg \
						sleep $h^h >[2]/dev/null
				} {
					echo 'System will once again sleep ' \
						^'with lid closed.'
				}
			}
		}
	} else {
		echo 'not a mobile device'
		result 1
	}
}

fn astat {|*|
	.d 'Display a status screen'
	.a '[UPDATE_TIME]  # seconds; default: 10; min: 0.1; max: 99.9'
	.c 'system'
	if {~ $* ()} {
		* = 10
	} else if {! echo $*|grep -q '^[0-9]\{0,2\}\(\.[0-9]\)\?$' \
								|| $* :eq 0} {
			throw error astat 'time?'
	}
	%with-terminal astat %with-quit {
		watch -c -t -p -n$* \
			'xs -c ''echo '^$*^' second update;d;load;thermal' \
				^';mem;addr;net;vol;vol-presets inq;det;pps' \
				^';tms;virts active'''
	}
}

fn bar {|*|
	.d 'Control the status bar'
	.a 'off'
	.a '(none)  # (re)start'
	.c 'system'
	if {~ $* off} {
		pkill i3status
	} else if {!~ $#* 0} {
		.usage bar
	} else {
		pkill i3status
		let (target = ~/.config/i3status/config; \
		interval = 5; load_threshold = `{nproc --ignore 1}; \
		opts = -ta l -bg gray10 -fn 'Noto Sans Medium-'^$INFO_FONTSIZE) {
			mkdir -p `` \n {dirname $target}
			rm -f $target
			cat >>$target <<EOF
# GENERATED

# storage group

EOF
			for mp (/ /home) {
				mountpoint -q $mp && cat >>$target <<EOF
order += "disk $mp"
disk "$mp" {
	format = "$mp; %avail"
	low_threshold = 15
	threshold_type = "percentage_avail"
}

EOF
			}
			cat >>$target <<EOF
# connectivity group

order += "wireless _first_"
wireless _first_ {
        format_up = "%essid; %quality %frequency"
        format_down = "WiFi"
}

order += "ethernet _first_"
ethernet _first_ {
        format_up = "Enet"
        format_down = "Enet"
}

order += "ipv6"
ipv6 {
	format_up = "IPv6"
	format_down = "IPv6"
}

order += "path_exists VPN"
path_exists VPN {
	path = "/proc/sys/net/ipv4/conf/tun0"
	format = "%title"
	format_down = "%title"
}

# energy group

order += "load"
load {
        format = "%1min %5min %15min"
	max_threshold = "$load_threshold"
}

# memory group

order += memory
memory {
	format = "%available"
	threshold_degraded = 30%
	threshold_critical = 10%
}

# presentation

general {
	output_format = "dzen2"
	separator = "|"
	color_separator = "#708090"
	color_good = "#2e8b57"
	color_degraded = "#cdbe70"
	color_bad = "#cd5555"
        colors = true
        interval = $interval
}
EOF
			exec {i3status >[2]/dev/null | stdbuf -o0 sed -e \
				's/fg(#cd5555)\(WiFi\|Enet\|IPv6\|VPN\)' \
				^'/fg(#505050)\1/g' -e 's/^.*$/^pa(20)&/' \
				| dzen2 $opts} &
		}
		true
	}
	# Tell cwmrc about the bar height.
	ed -s ~/.cwmrc <<'EOF'
g/^gap .* # GENERATED$/d
wq
EOF
	if {!~ $* off} {
		while {~ `{/usr/bin/xprop -name 'dzen title' \
							>[2]/dev/null} ()} {
			sleep 0.1
		}
	}
	printf >> ~/.cwmrc 'gap %d 1 1 1 # GENERATED'\n `%top-margin
	%restart-wm
}

fn battery {
	.d 'Show battery status'
	.c 'system'
	let (pspath = /sys/class/power_supply; full = 0; curr = 0; pcon = 0; \
		ef; ec; en; pn; st; dr) {
		for d ($pspath/BAT?) {
			access -d $d && {
				ef = `{cat $d/energy_full_design}
				ec = `{cat $d/energy_full}
				en = `{cat $d/energy_now}
				pn = `{cat $d/power_now}
				st = `{cat $d/status}
				full = `($full+$ec)
				curr = `($curr+$en)
				if {~ $st Discharging} {dr = $pn} else {dr = 0}
				pcon = `($pcon+$dr)
				printf '%s %.1s (%.2f); ' \
					`{basename $d} $st `(1.0*$ec/$ef)
			}
		}
		if {!~ $curr 0} {
			printf '%.1f W; ' `($pn/1000000.0)
			if {!~ $pcon 0} {
				printf '%.1f%% capacity (%.0f WH); ' \
						^'%.1f hours remain'\n \
					`(100.0*$curr/$full) \
					`($curr/1000000.0) \
					`(1.0*$curr/$pcon)
			} else {
				printf '%.1f%% capacity (%.0f WH); ' \
						^'not discharging'\n \
					`(100.0*$curr/$full) `($curr/1000000.0)
			}
		}
	}
}

fn cpuvulns {
	.d 'CPU vulnerabilities info'
	.c 'system'
	{
	echo 'Known vulnerabilities and mitigations on this platform:'
	printf ' %s, %s'\n `` \n {cat /proc/cpuinfo |grep '^model name' \
				|cut -d: -f2-|head -1} `` \n {uname -sr}
		for f /sys/devices/system/cpu/vulnerabilities/* {
			printf \n%s%s%s\n <=.%ar `{basename $f} <=.%an
			cat $f
		}
	}|less -RFX
}

fn d {
	.d 'Date/time (local, UTC, POSIX and TAI)'
	.c 'system'
	let (a = `` '' {grep \^Leap /usr/share/zoneinfo/leapseconds|cut -f6}; \
		s = `{date +%s}; pf; nf; p; n; l; t) {
		pf = `{grep -e + <<<$a}
		nf = `{grep -e - <<<$a}
		p = $#pf
		n = $#nf
		l = `(10+$p-$n)
		t = `($s+$l)
		printf %s\t%s\t%d\n+%d\t\t\t\t%s\t%d\n \
			`` \n {date --date=@$s +'%a %d %b %Y %R:%S %Z'} \
			`` \n {date --date=@$s -u +'%a %d %b %Y %R:%S UTC'} \
			$s \
			$l \
			`` \n {date --date=@$t -u +'%a %d %b %Y %R:%S TAI'} \
			$t
	}
}

fn dnf-get-source {|*|
	.d 'Get package source'
	.a 'PACKAGE'
	.c 'system'
	dnf download --source $*
	if {{~ $* *-devel*} && {!access -f -- $*^*src.rpm}} {
		let (no-devel = `` \n {echo $*|sed 's/-devel//'}) {
			if {access -f -- $no-devel^*.src.rpm} {
				echo 'Packed w/o -devel'
				* = $no-devel
			}
		}
	}
	access -f -d $* && {
		rm -f $*^*.src.rpm
		throw error dnf-get-source $* exists
	}
	mkdir $*
	mv $*^*.src.rpm $*
	fork {
		cd $*
		rpm2archive $*^*.src.rpm
		tar xf $*^*.src.rpm.tgz
		access -f -- .^$*^*.tar.gz && tar xf .^$*^*.tar.gz
		for f .* {
			!~ $f . .. && {
				let (vf = `` \n {echo $f|cut -c 2-}) {
					mv $f $vf
				}
			}
		}
	}
}

fn iso-burn {|*|
	.d 'Write a directory to a data CD or DVD.'
	.a 'DIRECTORY DEVICE'
	.a '-d  # list devices'
	.c 'system'
	if {~ $#* 2} {
		printf Data\t%s\n `{du -hs $*(1)|cut -d\t -f1}
		printf 'symlinks out-of-tree: %d'\n `{symlinks-out $*(1)|wc -l}
		%confirm n Proceed || throw error iso-burn 'Not confirmed'
		mkisofs -rational-rock -J -full-iso9660-filenames \
				-allow-leading-dots -allow-multidot $*(1) \
			| cdrecord dev=$*(2) -v --eject -
	} else if {~ $* -d} {
		echo Devices:
		cdrecord --devices >[2]/dev/null | {grep dev= || echo '(none)'}
	} else {
		.usage iso-burn
	}
}

fn iso-mount {|*|
	.d 'Mount an ISO volume.'
	.a 'DEVICE MOUNTPOINT'
	.c 'system'
	if {~ $#* 2} {
		sudo mount -t iso9660 -o ro $*(1) $*(2)
	} else {
		.usage iso-mount
	}
}

fn logs {|*|
	.d 'Show recent journal entries in a scrollable window'
	.a '[journalctl_OPTIONS]'
	.c 'system'
	.i 'scroll: Shift-Prior Shift-Next'
	result %with-terminal
	stq -t logs -e xs -c {%with-quit {
			scroll -- journalctl -f -o short-iso-precise \
						--no-hostname -n1000}} &
}

fn mail {
	.d 'Check inbox status'
	.c 'system'
	let (rc = <={fetchmail -c}) {
		~ $rc 0 1 || echo 'Check network and ~/.fetchmailrc.'
	}
	true
}

fn mem {
	.d 'Report memory availability'
	.c 'system'
	echo `{grep '^\(MemTotal\|MemFree\|MemAvailable\)' /proc/meminfo \
			|tr TFA tfa|sed '1,2s/$/; /'|sed 's/Mem//g' \
			|sed ':a;s/\b\([0-9]\+\)\([0-9]\{3\}\)\b/\1,\2/;ta'}
}

fn mi {|*|
	.d 'Meson introspect'
	.a 'BUILDDIR --targets'
	.a 'BUILDDIR --installed'
	.a 'BUILDDIR --buildsystem-files'
	.a 'BUILDDIR --buildoptions'
	.a 'BUILDDIR --tests'
	.a 'BUILDDIR --benchmarks'
	.a 'BUILDDIR --dependencies'
	.a 'BUILDDIR --projectinfo'
	.c 'system'
	let (go = true) {let (fn-nope = {$go && .usage mi; go = false}) {
		! access -d -- $*(1) && nope
		~ $#* 0 1 && nope
		!~ $*(2) --targets --installed -files --buildsystem-files \
			--buildoptions --tests --benchmarks --dependencies \
			--projectinfo && nope
		$go && meson introspect $*|jq -C .|less -iRFX
	}}
}

fn moninfo {|*|
	.d 'Show EDID info of all attached displays'
	.a '[-v]  # verbose listing'
	.c 'system'
	for e /sys/class/drm/*/edid {
		!~ `{cat $e|wc -c} 0 && {
			echo
			echo $e
			echo ----
			if {~ $* -v} {
				cat $e|edid-decode >[2=1]|awk '
BEGIN {section=1}
/^$/ {++section}
{if (section == 2) print}
'
			} else {
				cat $e|edid-decode >[2=1]|awk '
BEGIN {chroma=0}
/^.* interface$/ {print}
/^Maximum image size/ {print}
/^Gamma/ {print}
/^DPMS levels/ {print}
/^Supported color/ {print}
/^Default/ {print}
/^ / {if (chroma) print}
/^[^ ]/ {chroma=0}
/^Display x,y/ {print; chroma=1}
/^Monitor/ {print}
{}
'
			}
		}
	} |less -iFX
}

fn name {|*|
	.d 'Set prompt text and terminal title.'
	.a '[NAME]'
	.c 'system'
	.r 'prompt title'
	if {~ $* ()} {
		prompt ''
		title `{echo $TERM|sed 's/-256color.*//'}
	} else {
		prompt $*
		title $*
	}
}

fn net {|*|
	.d 'Network status'
	.a '[-a]'
	.c 'system'
	%with-terminal net {let (flag) {
		if {!~ $* -a} {flag = --active}
		nmcli --colors no --fields name,type,device \
			connection show $flag | tail -n+2 | %wt-pager
	}}
}

fn nmtui {
	.d 'Network Manager text UI'
	.c 'system'
	.f 'wrap'
	%with-terminal nmtui /usr/bin/nmtui
}

fn oc {
	.d 'Onscreen clock'
	.c 'system'
	%with-terminal oc %with-quit %without-cursor {
		watch -t -n 1 -p -c banner \\' '^\`date +%T\`\; \
						cal -n 3 --color=always
	}
}

fn on {
	.d 'List console logins'
	.c 'system'
	who -Huw
}

fn open {|*|
	.d 'Open a document'
	.a 'FILE'
	.c 'system'
	rifle $*
}

fn pers {
	.d 'Report count of active VMs, containers and terminal sessions'
	.c 'system'
	let (det-count = `{det >[2]/dev/null|wc -l}; \
	podman-count = `{podman ps -q|wc -l}; \
	tmux-count = `{tmux list-sessions >[2]/dev/null|grep -c '^[0-9]\+:'}; \
	virts-count = `{virts active >[2]/dev/null|wc -l} \
	) {
		echo det: $det-count^'; '^podman: $podman-count^'; ' \
				^tmux: $tmux-count^'; '^virts: $virts-count
	}
}

fn pipu {|*|
	.d 'Python installer with user directory'
	.a 'INSTALL_DIRECTORY pip_COMMAND_AND_OPTIONS'
	.c 'system'
	~ $USER root && throw error pipu 'do not run as root'
	if {~ $#* 0} {
		.usage pipu
	} else {let ((root-dir pip-args) = $*) {
		access -d -- $root-dir || \
			throw error pipu $root-dir 'not a directory'
		env PYTHONUSERBASE=$root-dir pip install --user $pip-args
	}}
}

fn pressure {
	.d 'Display resource pressure statistics'
	.c 'system'
	%with-terminal pressure {
	for d /proc/pressure/* {
		printf '* %s%s%s'\n <=.%as `{basename $d} <=.%an
		cat $d|sed -e 's/^\(.*\)\(=[0-9]\+\)\([0-9]\{6\}\)$/\1\2.\3/' \
			-e 's/^\(.*\)=\([0-9]\{6\}\)$/\1=0.\2/' \
			-e 's/^\(.*\)=\([0-9]\{5\}\)$/\1=0.0\2/' \
			-e 's/^\(.*\)=\([0-9]\{4\}\)$/\1=0.00\2/' \
			-e 's/^\(.*\)=\([0-9]\{3\}\)$/\1=0.000\2/' \
			-e 's/^\(.*\)=\([0-9]\{2\}\)$/\1=0.0000\2/' \
			-e 's/^\(.*\)=\([0-9]\{1\}\)$/\1=0.00000\2/'
	} | %wt-pager}
	# Refs:
	# https://facebookmicrosites.github.io/psi/docs/overview
	# https://lwn.net/Articles/759658/
}

fn ps2cs {
	.d 'Move primary selection to clipboard selection'
	.c 'system'
	let (s = `` '' {xsel -o -p}) {
		!~ $s () && {
			xsel -o -p|xsel -i -b
			xsel -c -p
		}
	}
}

fn recollq {|*|
	.d 'Search files by content'
	.a '[recollq_OPTIONS] QUERY'
	.c 'system'
	/usr/bin/recollq $*|less -iRFXS
}

fn rlb {
	.d 'List readline bindings'
	.c 'system'
	# Look, `bash` *does* have a purpose... ;)
	%with-terminal rlb {
		{
		echo ':[ vi movement-mode ('^\x7f^') ]'
		bash -c 'bind -pm vi-command'|grep -v -e '^#'
		echo ':'
		echo ':[ vi insert-mode (+) ]'
		bash -c 'bind -pm vi-insert'|grep -v -e '^#' -e self-insert
		echo ':'
		echo ':[ ~/.inputrc overrides, reflected above ]'
		grep '^\([^: ]\+:\|$if\|$else\|$endif\)' ~/.inputrc
		} | sed 's/^"\([^"]\+\)":/\1:/' \
			| grep -v -e '^\\e[^:]' | sed 's/^\\C-/C-/' \
			| sed 's/^\\e/ESC/' | sed 's/^ /SPC/' \
			| column -s: -t | tr \x7f : | less -iRFX
	}
}

fn speak {|*|
	.d 'Speak standard input, text or file'
	.a '[-p PRESET]  # text from standard input'
	.a '[-p PRESET] -f FILE  # ... file'
	.a '[-p preset] TEXT...  # ... command line'
	.a '-p  # list presets'
	.a '--wait  # wait for end of speech'
	.a '--stop  # stop speech'
	.c 'system'
	let (pidf = ~/.local/run/speak.pid; pf = ~/.config/speak.presets) {
		if {~ $*(1) -p && ~ $#* 1} {
			access -f $pf && cat $pf
		} else if {~ $* --wait} {
			access -f $pidf && %wait-file-deleted $pidf
			rm -f $pidf
		} else if {~ $* --stop} {
			access -f $pidf && pkill -s `{cat $pidf}
			rm -f $pidf
		} else {
			let (vparms; arg; f; voice; stretch; pitch) {
				if {~ $*(1) -p && $#* :ge 2} {
					access -f $pf || throw error speak \
								'no presets'
					(_ voice stretch pitch) = \
							`{grep '^'$*(2) $pf}
					* = $*(3 ...)
				}
				~ $voice () || vparms = $vparms \
						-voice $voice
				~ $stretch () || vparms = $vparms \
						-s duration_stretch=$stretch
				~ $pitch () || vparms = $vparms \
						-s int_f0_target_mean=$pitch
				if {~ $#* 0} {
					arg = -t `` \n {cat /dev/stdin}
				} else if {~ $*(1) -f} {
					if {!~ $#* 2 || !access -f -- $*(2)} {
						throw error speak 'file?'
					}
					arg = -f $*(2)
				} else {
					arg = -t $^*
				}
				f = `mktemp
				printf 'Rendering... '
				mimic $vparms $arg -o $f
				echo 'done'
				{
					printf %d $pid >$pidf
					play -G -q $f lowpass 3.5k highpass 150
					rm -f $pidf $f
				} &
			}
			true
		}
	}
}

fn swapflush {
	.d 'Flush swapfile(s)'
	.c 'system'
	sudo swapoff -a && sudo swapon -a
}

fn sysjournal {
	.d 'Follow system journal starting at most recent boot'
	.c 'system'
	%with-terminal sysjournal {
		journalctl -b --follow --no-tail >[2=1]|lnav -c ':goto 100%'
	}
}

fn sysrq {|*|
	.d 'System request keys'
	.a '-a  # Enable all sysrq keys until reboot'
	.a '-p  # Enable preset sysrq keys'
	.a '(none)  # List enabled sysrq functions'
	.c 'system'
	%with-terminal sysrq {
	let (mask = `{cat /proc/sys/kernel/sysrq}; desc = (
	# NOTE: Enabled key bindings are specific to the Fedora kernel.
	''  # placeholder
	'  Logging                                              [0..9]  0x002'
	'  Console                                               [k,r]  0x004'
	'  Kernel                                      [c,l,m,p,t,w,z]  0x008'
	'  Filesystems                                           [s,j]  0x010'
	'  Mountpoints                                             [u]  0x020'
	'  Signals                                             [e,f,i]  0x040'
	'  Power                                                 [b,o]  0x080'
	'  Scheduler                                               [n]  0x100'
	); \
	keys = (
	''  # placeholder
	'    0   set console log level (panic)'\n^ \
	'    ...'\n^ \
	'    9   set console log level (debug)'
	'    k   kill all programs on current console'\n^ \
	'    r   console keyboard mode XLATE (no raw)'
	'    c   crash kernel'\n^ \
	'    l   show backtrace on all active CPUs'\n^ \
	'    m   dump memory info'\n^ \
	'    p   dump registers and flags'\n^ \
	'    t   list current tasks'\n^ \
	'    w   list uninterruptable (blocked) tasks'\n^ \
	'    z   dump ftrace buffer'
	'    s   sync filesystems'\n^ \
	'    j   thaw filesystems'
	'    u   remount read-only'
	'    e   SIGTERM all processes except init'\n^ \
	'    f   kill an OOM process'\n^ \
	'    i   SIGKILL all processes except init'
	'    b   immediate reboot'\n^ \
	'    o   poweroff'
	'    n   make realtime tasks nice-able'
	); \
	mv; ms = 0) {
		# NOTE: Bit 0 of the mask does not "enable all" as documented.
		if {~ $* -a} {
			mask = 510
			sudo su -c 'echo '$mask^' > /proc/sys/kernel/sysrq'
			echo 'All sysrq keys enabled until reboot'
		}
		if {~ $* -p} {
			mask = `{calc `{grep '^kernel.sysrq' \
					/etc/sysctl.d/90-override.conf \
				| grep -o '[^ ]\+$'}}
			sudo su -c 'echo '$mask^' > /proc/sys/kernel/sysrq'
			echo 'Configured sysrq keys restored'
		}
		if {~ $mask 0} {
			throw error sysrq 'disabled'
		} else {
			echo '"Magic" system request                      ' \
				^'Mod1+Multi_key+…   mask'
			mv = 1
			while {!~ $mask 0} {
				if {~ `($mask%2) 1} {
					echo $desc(1)
					echo $keys(1)
					ms = `($ms+$mv)
				}
				mask = `($mask/2)
				mv = `($mv*2)
				desc = $desc(2 ...)
				keys = $keys(2 ...)
			}
			printf '%60s = %#05x'\n '/proc/sys/kernel/sysrq' $ms
			printf '%68s'\n \
				'config: /etc/sysctl.d/90-override.conf'
		} | %wt-pager -r
	}
	}
}

fn thermal {
	.d 'Summarize system thermal status'
	.c 'system'
	sensors >[2]/dev/null | grep -e '^Physical' -e '^Package' \
				-e '^Core' -e '^fan' | sed 's/ *(.*$//' \
				| sed 's/ \+/ /g' | column
}

fn timebar {|*|
	.d 'Control the clock bar'
	.a 'off'
	.a '(none)  # (re)start'
	.c 'system'
	if {~ $* off} {
		pkill i3status
	} else if {!~ $#* 0} {
		.usage timebar
	} else {
		pkill i3status
		let (target = ~/.config/i3status/config; interval = 1; \
		opts = -ta l -bg gray10 -fn 'Noto Sans Medium-'^$INFO_FONTSIZE) {
			mkdir -p `` \n {dirname $target}
			rm -f $target
			cat >>$target <<EOF
# GENERATED

# clock

order += "tztime utc"
order += "tztime local"

tztime utc {
	format = "%s %a %m-%d %H:%M %Z"
	timezone = "Etc/UTC"
}

tztime local {
	format = "%a %Y[d%j;w%V]-%m-%d %H:%M:%S %Z (%z)"
}

# presentation

general {
	output_format = "dzen2"
	separator = "|"
	color_separator = "#708090"
	color_good = "#b3b3b3"
        colors = true
        interval = $interval
}
EOF
			exec {i3status >[2]/dev/null | stdbuf -o0 sed -e \
				's/^\(.*^fg(\)\()[^^]\+\)$/' \
				^'^pa(20)\1#c0e0e0\2/' | dzen2 $opts} &
		}
		true
	}
	# Tell cwmrc about the bar height.
	ed -s ~/.cwmrc <<'EOF'
g/^gap .* # GENERATED$/d
wq
EOF
	if {!~ $* off} {
		while {~ `{/usr/bin/xprop -name 'dzen title' \
							>[2]/dev/null} ()} {
			sleep 0.1
		}
	}
	printf >> ~/.cwmrc 'gap %d 1 1 1 # GENERATED'\n `%top-margin
	%restart-wm
}

fn title {|*|
	.d 'Set terminal title'
	.a '[TITLE]'
	.c 'system'
	.r 'prompt name'
	$&echo -n \e]0\;^$^*^\a
}

fn tms {
	.d 'List tmux sessions'
	.c 'system'
	let (sl = `` \n {tmux list-sessions >[2]/dev/null}) {
		if {~ $sl ()} {
			echo 'No tmux sessions'
		} else {
			for s $sl {printf %s\n $s}
		}
	}
}

fn tss {|*|
	.d 'Terminal screen size utility'
	.a '-u  # update ROWS and COLUMNS environment vars'
	.a '-d  # delete ROWS and COLUMNS environment vars'
	.a '-q  # display ROWS and COLUMNS environment vars'
	.a '(none)  # show terminal size'
	.c 'system'
	switch $* (
	-d {COLUMNS = ; ROWS =}
	-u {(ROWS COLUMNS) = (`{tput lines} `{tput cols})}
	-q {var COLUMNS ROWS}
	{})
	~ $* () && {printf '%sx%s'\n `{tput cols} `{tput lines}}
}

fn where {
	.d 'Summarize user, host, tty, shell pid and working directory'
	.c 'system'
	printf '%s@%s[%s;%d]:%s'\n \
		$USER `{hostname -s} <={~~ `tty /dev/*} $pid `pwd
}

fn wifi {|*|
	.d 'WiFi access'
	.a 'available|connected|defined|show-ap|on|off'
	.a 'add SSID PASSWORD [NAME]'
	.a 'up|down SSID'
	if {~ $#* 0} {
		.usage wifi
	} else if {~ $1 <={%prefixes add} && ~ $#* 3 4} {
		let (name) {
			!~ $4 () && name = name $4
			nmcli device wifi connect $2 password $3 $name
		}
	} else if {~ $1 up} {
		nmcli conn up $2
	} else if {~ $1 down} {
		nmcli conn down $2
	} else if {~ $#* 1} {
		let (fn-check = {|body| \
		if {~ `{nmcli radio wifi} enabled} {
			$body
		} else {echo Off}
		}) {
			if {~ $1 <={%prefixes available}} {
				check {nmcli device wifi list}
			} else if {~ $1 <={%prefixes connected}} {
				check {nmcli device wifi list|grep '^[^ ]' \
					|sed 's/\([0-9]\+\) \(\(K\|M\|G\)' \
						^'bit\/s\)/\1'^\u'a0'^'\2/'\
					|column -t}
			} else if {~ $1 <={%prefixes defined}} {
				nmcli -t --fields name,type connection \
					|grep '.*:.*wireless'|cut -d: -f1
			} else if {~ $1 on} {
				nmcli radio wifi on
			} else if {~ $1 <={%prefixes off 2}} {
				nmcli radio wifi off
			} else if {~ $1 <={%prefixes show-ap}} {
				printf 'Scanning ...'\r
				nmcli -m tabular -f ssid,bssid,chan,freq, \
					^rate,signal,in-use device wifi \
					list --rescan yes \
				|grep -e '^SSID' -e ' \* ' \
				|sed -e 's/ \+IN-USE *$//' -e 's/ \* *$//' \
					-e 's/Mbit\/s//' -e 's/MHz//' \
				|column -t
			} else {.usage wifi}
		}
	} else {
		.usage wifi
	}
}

fn wlpq {
	.d 'Watch lpq until empty'
	.c 'system'
	grep -c '^no entries' >/dev/null <{lpq} || {
		lpq; echo; lpq +20 >/dev/null
	}
	echo 'lpq is empty'
}

fn xosview {|*|
	.d 'System resource meters'
	.a '[xosview_OPTIONS]'
	.c 'system'
	.f 'wrapper'
	%only-X
	result %with-terminal
	let (cf = ~/.local/share/xosview.fans; i) {
	if {%outdated $cf ~/.serverauth.*} {
		echo '! Generated file' >$cf
		systemd-detect-virt -q || \
		for d /sys/class/hwmon/hwmon?/fan?_input {
			i = `($i+1)
			f = `{basename $d _input}
			g = `{cat `{dirname $d}^/name}
			{
				echo xosview\*lmstemp$i^: $f
				echo xosview\*lmsname$i^: $g
				echo xosview\*lmstempLabel$i^: FAN$i
			} >>$cf
		}
	}
	}
	/usr/bin/xosview $*
}
