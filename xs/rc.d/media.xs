fn afa {|*|
	.d 'Audio file analyzer'
	.a 'TRACK_FILE'
	.c 'media'
	%with-terminal afa {let (track = $^*) {
		~ $track '' && throw error afa 'track?'
		{
			switch `{echo $track|sed s'/^.*\.//g'} (
			mp3 {id3info $track}
			{soxi $track}
			)
			echo '*** analysis'
			sox $track -n stats >[2=1]
		} | %wt-pager -S
	}}
}

fn artwork {|*|
	.d 'Display artwork for audio track'
	.a 'TRACK_FILE'
	.c 'media'
	result %with-terminal
	let (track = $^*; sxiv_opts = -g 720x720 -bq) {
		~ $track '' && throw error artwork 'track?'
		%with-tempfile pic {
			exiftool -b -Picture $track >$pic
			if {~ `{file $pic} image} {
				sxiv $sxiv_opts $pic &
			} else {
				sxiv $sxiv_opts `` \n {dirname \
					$track}^/*.^(png jpg) &
			}
			sleep 0.5
		}
	}
}

fn bluetoothctl {|*|
	.d 'Bluetooth control'
	.a '[bluetoothctl_OPTIONS]'
	.c 'media'
	.f 'wrap'
	%with-terminal bluetoothctl /usr/bin/bluetoothctl $*
}

fn gallery {|*|
	.d 'Random slideshow'
	.a 'PATH [DELAY]'
	.c 'media'
	%only-X
	if {~ $#* 0} {
		.usage gallery
	} else {let (dir = $(1); time = $(2)) {
		~ $time () && time = 5
		find -L $dir -type f|shuf \
					|sxiv -qifb -sf -S$time >[2]/dev/null &
	}}
}

fn glava {|*|
	.d 'Audio spectrum display'
	.a 'linear  # default; LF outside; horizontal'
	.a 'bars  # vertical; RHS base; top is right channel'
	.a 'mono  # vertical; RHS base; LF bottom; mixed channels'
	.a 'radial  # LF left; top is left channel'
	.a 'circle  # LF bottom'
	.c 'media'
	.f 'wrap'
	result %with-terminal
	if {~ $* <={%prefixes linear} || ~ $* ()} {
		/usr/bin/glava -m graph -r 'setgeometry 0 0 1200 200' &
	} else if {~ $* <={%prefixes bars} || ~ $* ()} {
		/usr/bin/glava -m bars -r 'setgeometry 0 0 200 600' &
	} else if {~ $* <={%prefixes mono} || ~ $* ()} {
		/usr/bin/glava -m mono -r 'setgeometry 0 0 200 600' &
	} else if {~ $* <={%prefixes radial} || ~ $* ()} {
		/usr/bin/glava -m radial -r 'setgeometry 0 0 675 675' &
	} else if {~ $* <={%prefixes circle} || ~ $* ()} {
		/usr/bin/glava -m circle -r 'setgeometry 0 0 675 675' &
	} else {
		.usage glava
	}
}

fn grayview {|*|
	.d 'View image in grayscale'
	.a 'FILE ...'
	.c 'media'
	%only-X
	if {~ $#* 0} {
		.usage grayview
	} else {
		let (tf; _; ext) {
			for f $* {
				unwind-protect {
					(_ ext) = <={~~ $f *.*}
					tf = `mktemp^.$ext
					convert $f -type grayscale $tf
					sxiv -qb $tf
				} {
					rm -f $tf
				}
			}
		}
	}
}

fn image {|*|
	.d 'Display image'
	.a 'FILE ...'
	.c 'media'
	%only-X
	if {~ $#* 0} {
		.usage image
	} else {
		sxiv -qb $* &
	}
}

fn media-duration {|*|
	.d 'Report playback duration of media file'
	.a 'FILE...'
	.a '-t FILE...  # total'
	.a '-d DIRECTORY'
	.c 'media'
	if {~ $*(1) -t} {
		let (th = 0; tm = 0; ts = 0; tt = 0; ip) {
			%with-read-lines <{media-duration $*(2 ...)} {|line|
				let ((h m s t _) = <={~~ $line *:*:*.*\ *}) {
					th = `($th+$h)
					tm = `($tm+$m)
					ts = `($ts+$s)
					tt = `($tt+$t)
				}
			}
			ip = <={%intpart `($tt/1000.0)}
			ts = `($ts+$ip)
			tt = <= {%intpart `($tt%1000.0)}
			ip = <={%intpart `($ts/60.0)}
			tm = `($tm+$ip)
			ts = <={%intpart `($ts%60.0)}
			ip = <={%intpart `($tm/60.0)}
			th = `($th+$ip)
			tm = <={%intpart `($tm%60.0)}
			printf %02d:%02d:%02d.%03d\n $th $tm $ts $tt
		}
	} else if {~ $*(1) -d} {
		media-duration $*(2)
		media-duration -t $*(2)
	} else {
		mediainfo --Output=General\;%Duration/String3%\ %CompleteName%\\n $*
	}
}

fn midi {|*|
	.d 'Play MIDI files'
	.a 'FILE ...'
	.c 'media'
	if {~ $#* 0} {
		.usage midi
	} else {let (s; p) { unwind-protect {
			fluidsynth -a pulseaudio -m alsa_seq -s -i -l \
				/usr/share/soundfonts/FluidR3_*.sf2 \
				>/dev/null >[2=1] &
			s = $apid
			sleep 1
			p = `{aplaymidi -l|grep FLUID|cut -d' ' -f1}
			for f $* {aplaymidi -p $p $f}
		} {
			kill $s
		}
	}}
}

fn mpvl {|*|
	.d 'Movie player w/ volume leveler'
	.a '[mpv_OPTIONS] FILE ...'
	.c 'media'
	%only-X
	if {~ $#* 0} {
		.usage mpvl
	} else {
		/usr/bin/mpv --profile=leveler $*
	}
}

fn mtm {|*|
	.d 'Display metadata for media track'
	.a 'TRACK_FILE'
	.c 'media'
	.r 't'
	%with-terminal mtm {let (track = $^*) {
		~ $track () && throw error mtm 'track?'
		mediainfo $track|%wt-pager -S
	}}
}

fn music {|*|
	.d 'Play music'
	.a '[mpv_OPTIONS] PATH'
	.c 'media'
	/usr/bin/mpv --profile=music $*

}

fn newsounds-play {
	.d 'Play stream from New York Public Radio WNYC "New Sounds"'
	.c 'media'
	.r 'newsounds'
	result %with-terminal
	stq -t newsounds-play -g 72x3 -e xs -c 'mpv --volume=100' \
		^' --term-status-msg= http://www.wnyc.org/stream/q2/mp3.pls' &
}

fn noise {|*|
	.d 'Audio noise generator'
	.a '[white|pink|brown [LEVEL_DB]]'
	.a '(none)  # pink -30'
	.i 'LEVEL_DB ≤ -9'
	.c 'media'
	let (pc = $*(1); pl = $*(2); pad; volume) {
		~ $pc () && pc = pink
		~ $pl () && pl = -30
		switch $pc (
		white {pad = -10}
		pink {pad = -4}
		brown {pad = -8}
		{throw error noise 'color?'}
		)
		if {$pl :gt -9} {throw error noise 'level?'}
		volume = `($pl + $pad + 9)
		%without-echo %with-quit {
			play -n -q -t s16 -r 44100 -c 2 - \
				synth -n $pc^noise vol $volume dB
		}
	}
}

fn painfo {
	.d 'PulseAudio information'
	.c 'media'
	%with-terminal painfo {
		pactl list \
		|grep -e '^[^=]\+#[0-9]' -e '\(Argument\|Client\|counter' \
			^'\|Driver\|Flags\|Format\|Index\|Latency\|Map' \
			^'\|method\|Module\|Muted\|Name\|Port\|Profile' \
			^'\|Source\|Specification\|State\|Steps\|Volume\):' \
		|grep -v 'Argument: $' \
		|sed 's/^[A-Z].*$/\n'^<=.%as^'&'^<=.%an^'/' \
		|%wt-pager
	}
}

fn paloop {|*|
	.d 'PulseAudio loop manager'
	.a 'create|delete'
	.a 'purge  # delete all loops'
	.c 'media'
	.i 'NOTE: A loop to the `Monitor` sink from a source monitor will'
	.i 'have its latency set to match that of the source.'
	if {~ $^* <={%prefixes create}} {
		let (sources = `` \n {pactl list sources short|cut -f1,2}; \
		sinks = `` \n {pactl list sinks short|cut -f1,2}; \
		as = <=.%as; an = <=.%an; \
		sids; dids; src; dst; srcname; dstname \
		) {
			printf %sSources%s\n $as $an
			for s $sources {
				printf %s\n <={%wrap 72 \t $s}
				sids = $sids `{echo $s|cut -f1}
			}
			printf \n%sSinks%s\n $as $an
			for d $sinks {
				printf %s\n <={%wrap 72 \t $d}
				dids = $dids `{echo $d|cut -f1}
			}
			printf \n'from source [%s]? ' <={%flatten ', ' $sids}
			src = <=read
			~ $src '' && throw error paloop 'canceled'
			~ $src $sids || throw error paloop 'invalid'
			for s $sources {
				srcname = $srcname <={~~ $s $src\t*}
			}
			mon_src_latency = `{pactl list sinks|awk '
BEGIN {f=0}
/Monitor Source: '^$srcname^'/ {f=1; next}
/Monitor Source:/ {f=0}
/Latency: / {if (f) {print int($2/1000+0.5); exit}}'
			}
			printf 'to sink [%s]? ' <={%flatten ', ' $dids}
			dst = <=read
			~ $dst '' && throw error paloop 'canceled'
			~ $dst $dids || throw error paloop 'invalid'
			for d $sinks {
				dstname = $dstname <={~~ $d $dst\t*}
			}
			if {!~ $mon_src_latency () && !~ $mon_src_latency 0 \
						&& ~ $dstname Monitor} {
				echo Matched $mon_src_latency ms monitor \
								source latency
				pactl load-module module-loopback \
					latency_msec=$mon_src_latency \
					source=$srcname \
					sink=$dstname
			} else {
				pactl load-module module-loopback \
					source=$srcname \
					sink=$dstname
			}
		}
	} else if {~ $^* <={%prefixes delete}} {
		let (loops = `` \n {pactl list modules short \
						|grep module-loopback}; \
		lids; lid \
		) {
			printf %sLoops%s\n <=.%as <=.%an
			for l $loops {
				printf %s\n <={%wrap 72 \t $l}
				lids = $lids `{echo $l|cut -f1}
			}
			printf \n'delete loop [%s]? ' <={%flatten ', ' $lids}
			lid = <=read
			~ $lid '' && throw error paloop 'canceled'
			~ $lid $lids || throw error paloop 'invalid'
			pactl unload-module $lid
		}
	} else if {~ $^* <={%prefixes purge}} {
		let (loops = `` \n {pactl list modules short \
						|grep module-loopback}; \
		lid \
		) {
			%confirm n 'Purge all loops' \
					|| throw error paloop 'canceled'
			for l $loops {
				printf %s\n <={%wrap 72 \t $l}
				lid = `{echo $l|cut -f1}
				pactl unload-module $lid
			}
			echo 'All loops deleted'
		}
	} else {
		.usage paloop
	}
}

fn pamixer {|*|
	.d 'Pulse Audio mixer'
	.a '[pamixer_OPTIONS]'
	.c 'media'
	%with-terminal pamixer %preserving-title {
		/usr/local/bin/pamixer --color 1 $* || {
			throw error pamixer 'disconnected'
			~ $WITH_TERMINAL () || sleep 3
		}
	}
}

fn paroute {
	.d 'Route PulseAudio output'
	.c 'media'
	%with-terminal paroute {
		let (rcl = `` \n {pactl list short clients \
			|grep '^[0-9]\+\W\+protocol-native\.c.*$'|cut -f1,3}; \
		clients; sinks; cids; sids; \
		as = <=.%as; an = <=.%an) {
			%with-read-lines <{pactl list short sink-inputs \
						|grep 'protocol-native\.c' \
						|cut -f 1,3} {|line|
				let ((siid cid) = <={%split \t $line}) {
					for c $rcl {
						let ((ccid cnm) = \
							<={%split \t $c}) {
							if {~ $ccid $cid} {
								clients = \
								$clients \
								$siid^\t^$cnm
							}
						}
					}
				}
			}
			printf %sClients%s\n $as $an
			for c $clients {
				echo $c
				let ((cl _) = <={%split \t $c}) {
					cids = $cids $cl
				}
			}
			printf \n%sSinks%s\n $as $an
			sinks = `` \n {pactl list short sinks|grep \
				'module-\(alsa-card\|bluez5-device\)\.c' \
				|cut -f 1,2}
			for s $sinks {
				echo $s
				let ((si _) = <={%split \t $s}) {
					sids = $sids $si
				}
			}
			printf \n'route client [%s]? ' <={%flatten ', ' $cids}
			clnt = <=read
			~ $clnt '' && throw error paroute 'canceled'
			~ $clnt $cids || throw error paroute 'invalid'
			printf 'to sink [%s]? ' <={%flatten ', ' $sids}
			sink = <=read
			~ $sink '' && throw error paroute 'canceled'
			~ $sink $sids || throw error paroute 'invalid'
			pactl move-sink-input $clnt $sink
		}
	}
}

fn pdfposter {|*|
	.d 'Split a PDF poster to multiple letter-size sheets with cut marks'
	.a '[-s SCALE_FACTOR] PDF_INFILE PDF_OUTFILE'
	.c 'media'
	.f 'wrap'
	if {!~ $#* 2 4} {.usage pdfposter}
	let (scale = 1.0; in; out) {
		~ $*(1) -s && {scale = $*(2); * = $*(3 ...)}
		(in out) = $(1 2)
		access -f -- $in || throw error 'file?'
		# Ref: http://leolca.blogspot.com/2010/06/pdfposter.html
		%with-suffixed-tempfile tf .pdf {
			%with-throbber 'Processing ... ' {
				/usr/bin/pdfposter -m190x254mm -s $scale $in $tf
				pdflatex <<EOF
\documentclass{article}
% Support for PDF inclusion
\usepackage[final]{pdfpages}
% Support for PDF scaling
\usepackage{graphicx}
\usepackage[dvips=false,pdftex=false,vtex=false]{geometry}
\geometry{
   paperwidth=190mm,
   paperheight=254mm,
   margin=2.5mm,
   top=2.5mm,
   bottom=2.5mm,
   left=2.5mm,
   right=2.5mm,
   nohead
}
\usepackage[cam,letter,center,dvips]{crop}
\begin{document}
% Globals: include all pages, don't auto scale
\includepdf[pages=-,pagecommand={\thispagestyle{plain}}]{$tf}
\end{document}
EOF
			}
		}
		mv texput.pdf $out
		rm -f texput.*
		echo 'Output on' $out
	}
}

fn pulseeffects {|*|
	.d 'PulseAudio effects rack'
	.a '[stop]'
	.a '[check]'
	.a '(none)  # show rack'
	.c 'media'
	.i 'Takes tens of seconds to be ready for first-time use.'
	result %with-terminal
	if {~ $* <= {%prefixes check}} {
		if {pgrep -c pulseeffects >/dev/null} {
			printf 'running'
			if {pactl list short sinks|grep -qe 'PulseEffects'} {
				echo '; ready'
			} else {
				echo '; not yet ready'
			}
		} else {
			echo 'not running'
		}
	} else if {~ $* <={%prefixes stop}} {
		if {pgrep -c pulseeffects >/dev/null} {
			pkill pulseeffects
			echo 'stopped'
		} else {
			echo 'not running'
		}
	} else {
		pgrep -c pulseeffects >/dev/null \
			|| {/usr/bin/pulseeffects --gapplication-service &}
		pactl list short sinks|grep -qe 'PulseEffects' \
			|| report pulseeffects 'Starting. Be very patient...'
		/usr/bin/pulseeffects >[2]/dev/null &
	}
}

fn sonic-visualiser {|*|
	.d 'Audio file explorer'
	.a '[sonic-visualiser_OPTIONS]'
	.c 'media'
	.f 'wrap'
	result %with-terminal
	/usr/bin/sonic-visualiser $* >[2]/dev/null
}

fn vol {|*|
	.d 'Show/set volume of default PulseAudio output'
	.a '[%VOLUME]'
	.c 'media'
	if {~ $#* 1} {
		/usr/local/bin/pamixer --set-volume $*
	} else {
		if {~ `{/usr/local/bin/pamixer --get-mute} 1} {
			report Volume muted
		} else {
			report Volume `{/usr/local/bin/pamixer --get-volume \
				|cut -d\  -f1}^%
		}
	}
}
