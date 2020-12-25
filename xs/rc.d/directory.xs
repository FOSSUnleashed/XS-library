fn dt {|*|
	.d 'List top directory usage'
	.a '[-a] [DIR]'
	.c 'directory'
	let (eo = --exclude './.*') {
		if {~ $*(1) -a} {eo = ; * = $*(2 ...)}
		du $eo -t1 -h -d1 $*|grep -vE '^[.0-9KMGTPEZY]+'\t'\.$' \
			|sort -h -r -k1|head -15
	} | less -iRFX
}

fn doc {|*|
	.d 'pushd to documentation directory of package'
	.a 'PACKAGE_NAME_GLOB'
	.a '-n PACKAGE_NAME'
	.c 'directory'
	if {~ $#* 0} {
		.usage doc
	} else if {~ $*(1) -n} {
		doc /$*(2)^\$
	} else if {!~ $* ()} {
		let (pl) {
			pl = `{find -L /usr/share/doc /usr/local/share/doc \
				-mindepth 1 -maxdepth 1 -type d \
				|grep -i '/usr.*/share/doc.*'^$*}
			if {~ $#pl 1} {
				pushd $pl
			} else if {~ $#pl ???*} {
				throw error doc 'more than 99 matches'
			} else {
				for p ($pl) {echo `{basename $p}}
				echo $#pl matches
			}
		}
	}
}

fn la {|*|
	.d 'ls -A'
	.c 'directory'
	.r 'll ls lt'
	ls -A $*
}

fn ll {|*|
	.d 'ls -lh'
	.c 'directory'
	.r 'la ls lt'
	ls -lh $*
}

fn ls {|*|
	.d 'ls'
	.c 'directory'
	.a '[[-O] ls_ARGS]  # -O: no directories-first'
	.r 'la ll lt'
	let (group = --group-directories-first; arg; lsargs) {
		for arg $* {
			if {~ $arg -O} {
				group =
			} else {lsargs = $lsargs $arg}
		}
		if {test -t 1} {
			/usr/bin/ls -C -v --color=yes $group $lsargs \
								|less -iRFX
		} else {
			/usr/bin/ls $group $lsargs
		}
	}
}

fn lt {|*|
	.d 'ls -lhtr'
	.c 'directory'
	.r 'la ll ls'
	ls -lhtr $*
}

fn src {|*|
	.d 'pushd to K source directories'
	.a '[NAME]'
	.a '(none)  # list source directories'
	.c 'directory'
	if {~ $#* 0} {
		find /usr/local/src -maxdepth 1 -mindepth 1 -type d \
			|xargs -I\{\} basename \{\}|column -c `{tput cols}
	} else {
		if {access -d /usr/local/src/$*} {
			pushd /usr/local/src/$*
		} else {echo 'not in /usr/local/src'}
	}
}

fn symlinks-out {|*|
	.d 'List symbolic links having out-of-tree targets'
	.a 'DIRECTORY'
	.c 'directory'
	let (r = `` \n {cd $*; pwd}; t) {
		for l `` \n {find $r -type l} {
			t = `` \n {readlink -f $l}
			~ $t $r^* || echo $l '->' $t
		}
	}
}

fn td {|*|
	.d 'Display tree of directories'
	.a '[-L LEVELS] [DIRECTORY]'
	.c 'directory'
	.r 'treec'
	tree -dC $* | less -iRFX
}

fn treec {|*|
	.d 'Display filesystem tree'
	.a '[-L LEVELS] [DIRECTORY]'
	.c 'directory'
	.r 'td'
	tree --du -vhpugDFC $* | less -iRFX
}
