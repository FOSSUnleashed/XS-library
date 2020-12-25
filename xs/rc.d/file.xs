fn abrowse {|*|
	.d 'Browse archive file'
	.a 'FILE'
	.c 'file'
	if {!~ $#* 1} {
		.usage abrowse
	} else {
		%with-tempdir mp {
			archivemount -o readonly $* $mp && unwind-protect {
				fork {
					cd $mp
					ls -o --color=yes|tail -n+2|less -RFXS
					echo <=.%as^'Browsing content in new' \
						^' shell; exit to end'^<=.%an
					env fn-cd='{|*| if {~ $* ()} {$&cd ' \
						^$mp^'} else {$&cd $*}}' \
						history= xs
				}
			} {
				fusermount -u $mp
			}
		}
	}
}

fn cccs {|*|
	.d 'Check C comment spelling'
	.a 'FILE...'
	.c 'file'
	.i 'Print comment words not known to be correctly spelled.'
	.r 'lmw'
	if {~ $* ()} {
		.usage cccs
	} else if {~ $#* 1} {
		clang -Xclang -ast-dump -fsyntax-only -fparse-all-comments \
				-fno-color-diagnostics $* >[2]/dev/null  \
			|grep -o 'Text=".*$'|cut -c6- \
			|aspell list|sort -u|column
	} else {
		for f $* {
			echo '; '^$f
			cccs $f
		}
	}
}

fn cr2lf {|*|
	.d 'Convert a file having CR line endings'
	.a 'FILE'
	.c 'file'
	.r 'crlf2lf'
	if {!~ $#* 1} {
		.usage cr2lf
	} else {
		let (f = `mktemp) {
			cat $* | tr \r \n > $f
			mv $f $*
		}
	}
}

fn crlf2lf {|*|
	.d 'Convert a file having CRLF line endings'
	.a 'FILE'
	.c 'file'
	.r 'cr2lf'
	if {!~ $#* 1} {
		.usage crlf2lf
	} else {
		let (f = `mktemp) {
			cat $* | tr -d \r > $f
			mv $f $*
		}
	}
}

fn deb2rpm {|*|
	.d 'Convert a .deb archive to .rpm'
	.a 'DEB_FILE'
	.c 'file'
	.i 'Assumptions: Same arch; binary package; for use on this host;'
	.i 'archive filename prefix (to version) same as package name.'
	if {!~ $#* 1} {
		.usage deb2rpm
	} else {
		let (base = `{cd `{dirname $*}; pwd}; arch = `arch; \
		fn-pm = {|b l| escape {|fn-return| for d $l {
					if {~ $b $d^* && !~ $d $b} {return $d}}
		}}) {
			sudo alien -rg $*
			pkg = <={pm `{basename $*} `` \n ls}
			~ $pkg () && throw error deb2rpm \
							'can not match package'
			echo Base: $base
			echo Matched package: $pkg
			access -f $pkg^-*^.$arch^.rpm && {
				sudo rm -rf $pkg
				throw error deb2rpm \
						$pkg^-*^.$arch^.rpm^' exists'
			}
			fork {
				cd $pkg
				sudo sed -i 's|%dir "[^"]\+"|#&|g' \
								$pkg^-*^.spec
				sudo rpmbuild --quiet \
						--buildroot $base^/$pkg \
						--target $arch -bb \
						$base^/$pkg^/$pkg^-*^.spec
			}
		}
	}
}

fn dots {|*|
	.d 'Display dots in place of text lines'
	.a '[MULTIPLIER]'
	.c 'file'
	~ $* () && * = 1
	let (n = 0; m = 0; t = 0) {
		while {!~ <=read ()} {
			t = `($t+1)
			m = `($m+1)
			~ $m $* && {
				m = 0
				n = `($n+1)
				printf .
				~ $n 72 && {printf \n; n = 0}
			}
		}
		printf \n'{%d}'\n $t
	}
}

fn frompkg {|*|
	.d 'Show name of package which provided a file'
	.a 'FILE'
	.c 'file'
	~ $* /lib* && * = \*^$*
	dnf -q provides $*|grep -v -e '^Repo' -e '^Matched' -e '^Filename' \
				-e '^Provide' -e '^$'|cut -d: -f1|sort|uniq
}

fn hd {|*|
	.d 'Simple hex dump'
	.a '[FILE]'
	.c 'file'
	if {$#* :gt 1} {
		.usage hd
	} else {
		hexdump $* -e '"%07.7_Ax  (%_Ad)\n"' \
			-e '"%07.7_ax  " 8/1 "%02x " "  " 8/1 "%02x " "\n"'
	} | less -iRFXS
}

fn import-abook {|*|
	.d 'Import vcard to abook'
	.a 'VCARD_FILE'
	.c 'file'
	if {~ $#* 0} {
		.usage import-abook
	} else {
		access -f ~/.abook/addressbook \
			&& mv ~/.abook/addressbook ~/.abook/addressbook-OLD
		abook --convert --infile $* --informat vcard \
			--outformat abook --outfile ~/.abook/addressbook
		chmod 600 ~/.abook/addressbook
	}
}

fn lddeps {|*|
	.d 'List dynamic libraries required by an ELF executable'
	.a 'ELF_EXECUTABLE...'
	.c 'file'
	ldd $*|grep /|cut -d \( -f1|sed 's|^[^/]\+||'
}

fn lmw {|*|
	.d 'List misspelled words'
	.a 'FILE...'
	.c 'file'
	.i 'Print words not known to be correctly spelled.'
	.r 'cccs'
	if {~ $* ()} {
		.usage lmw
	} else if {~ $#* 1} {
		if {file $*|grep -q text} {
			aspell list <$*|sort -u|column
		} else {
			echo ';- not text'
		}
	} else {
		for f $* {
			echo '; '^$f
			lmw $f
		}
	}
}

fn lpman {|man|
	.d 'Print a man page'
	.a 'PAGE'
	.c 'file'
	.r 'lpmd lporg lprst'
	if {!~ $#man 1} {
		.usage lpman
	} else {
		env MANWIDTH=80 man $man | sed 's/^.*/    &/' \
			| lpr -o page-top=60 -o page-bottom=60 \
				-o page-left=60 -o lpi=8 -o cpi=12
	}
}

fn lpmd {|md|
	.d 'Print a markdown file'
	.a 'FILE'
	.c 'file'
	.r 'lpman lporg lprst'
	if {!~ $#md 1} {
		.usage lpmd
	} else {
		cmark $md | w3m -T text/html -cols 80 | sed 's/^.*/    &/' \
			| lpr -o page-top=60 -o page-bottom=60 \
				-o page-left=60 -o lpi=8 -o cpi=12
	}
}

fn lporg {|*|
	.d 'Print an org file'
	.a 'ORG_FILE'
	.c 'file'
	.r 'lpman lpmd lprst'
	if {!~ $#* 1} {
		.usage orgv
	} else if {!access -f $*} {
		echo 'file?'
	} else {
		go-org $* html \
			| w3m -T text/html -cols 80 \
			| lpr -o page-top=60 -o page-bottom=60 \
				-o page-left=60 -o lpi=8 -o cpi=12
	}
}

fn lprst {|rst|
	.d 'Print a reStructuredText file'
	.a 'FILE'
	.c 'file'
	.r 'lpman lpmd lporg'
	if {!~ $#rst 1} {
		.usage lprst
	} else {
		rst2html -r 4 $rst | w3m -T text/html -cols 80 \
			| sed 's/^.*/    &/' \
			| lpr -o page-top=60 -o page-bottom=60 \
				-o page-left=60 -o lpi=8 -o cpi=12
	}
}

fn md2pdf {|*|
	.d 'Render Markdown file as PDF'
	.a 'MARKDOWN_FILE'
	.c 'file'
	.r 'org2pdf rst2pdf rtf2pdf'
	if {!~ $#* 1} {
		.usage md2pdf
	} else if {!access -f $*} {
		echo 'file?'
	} else {
		%with-tempdir html {
			let (f = `` \n {basename $*}; \
			popts = -s letter -L 0.5in -T 0.3in -R 0.5in -B 0.3in \
			) {
				cmark $* > $html^/$f^.html
				ed -s $html^/$f^.html <<'EOF'
1i
<meta charset="utf-8"/>
.
wq
EOF
				wkhtmltopdf $popts $html^/$f^.html $f^.pdf
			}
		}
	}
}

fn mdv {|*|
	.d 'Markdown file viewer'
	.a 'MARKDOWN_FILE'
	.c 'file'
	.r 'orgv rstv rtfv'
	if {!~ $#* 1} {
		.usage mdv
	} else if {!access -f $*} {
		echo 'file?'
	} else {
		cmark $* | w3m -X -o confirm_qq=0 -T text/html -cols 80
	}
}

fn org2pdf {|*|
	.d 'Render org file as PDF'
	.a 'ORG_FILE'
	.c 'file'
	.r 'md2pdf rst2pdf rtf2pdf'
	if {!~ $#* 1} {
		.usage org2pdf
	} else if {!access -f $*} {
		echo 'file?'
	} else {
		%with-tempdir html {
			let (f = `` \n {basename $*}; \
			popts = -s letter -L 0.5in -T 0.3in -R 0.5in -B 0.3in \
			) {
				go-org $* html-chroma > $html^/$f^.html
				wkhtmltopdf $popts $html^/$f^.html $f^.pdf
			}
		}
	}
}

fn orgv {|*|
	.d 'org file viewer'
	.a 'ORG_FILE'
	.c 'file'
	.r 'mdv rstv rtfv'
	if {!~ $#* 1} {
		.usage orgv
	} else if {!access -f $*} {
		echo 'file?'
	} else {
		go-org render $* html-chroma \
			| w3m -X -o confirm_qq=0 -T text/html -cols 80
	}
}

fn qpdec {|*|
	.d 'Decode quoted-printable text file'
	.a 'FILE'
	.c 'file'
	.r 'qpenc'
	if {!~ $#* 1} {
		.usage qpdec
	} else {
		cat $*|perl -MMIME::QuotedPrint=decode_qp \
						-e 'print decode_qp join"",<>'
	}
}

fn qpenc {|*|
	.d 'Encode text file as quoted-printable'
	.a 'FILE'
	.c 'file'
	.r 'qpdec'
	if {!~ $#* 1} {
		.usage qpenc
	} else {
		cat $*|perl -MMIME::QuotedPrint=encode_qp \
						-e 'print encode_qp join"",<>'
	}
}

fn rst2pdf {|*|
	.d 'Render reStructuredText file as PDF'
	.a 'RST_FILE'
	.c 'file'
	.r 'md2pdf org2pdf rtf2pdf'
	if {!~ $#* 1} {
		.usage rst2pdf
	} else if {!access -f $*} {
		echo 'file?'
	} else {
		%with-tempdir html {
			let (f = `` \n {basename $*}; \
			popts = -s letter -L 0.5in -T 0.3in -R 0.5in -B 0.3in \
			) {
				rst2html -r 4 $* > $html^/$f^.html
				wkhtmltopdf $popts $html^/$f^.html $f^.pdf
			}
		}
	}
}

fn rstv {|*|
	.d 'reStructuredText file viewer'
	.a 'RST_FILE'
	.c 'file'
	.r 'mdv orgv rtfv'
	if {!~ $#* 1} {
		.usage rstv
	} else if {!access -f $*} {
		echo 'file?'
	} else {
		rst2html -r 4 $* | w3m -X -o confirm_qq=0 -T text/html -cols 80
	}
}

fn rtf2pdf {|*|
	.d 'Render Rich Text Format file as PDF'
	.a 'RTF_FILE'
	.c 'file'
	.r 'md2pdf org2pdf rst2pdf'
	if {!~ $#* 1} {
		.usage rtf2pdf
	} else if {!access -f $*} {
		echo 'file?'
	} else {
		%with-tempdir html {
			let (f = `` \n {basename $*}; \
			popts = -s letter -L 0.5in -T 0.3in -R 0.5in -B 0.3in \
			) {
				unrtf --html $* > $html^/$f^.html
				wkhtmltopdf $popts $html^/$f^.html $f^.pdf
			}
		}
	}
}

fn rtfv {|*|
	.d 'Rich Text Format viewer'
	.a 'RTF_FILE'
	.c 'file'
	.r 'mdv orgv rstv'
	if {!~ $#* 1} {
		.usage rtfv
	} else if {!access -f $*} {
		echo 'file?'
	} else {
		unrtf --html $* | w3m -X -o confirm_qq=0 -T text/html -cols 80
	}
}


fn shuffle {|*|
	.d 'Shuffled list of files in directory'
	.a 'DIRECTORY [FILTER_GLOB]'
	.c 'file'
	let (dir = $*(1); filt = $*(2)) {
		~ $filt () && filt = '*'
		find -L $dir -type f -iname $filt \
			|shuf|awk '/^[^/]/ {print "'`pwd'/"$0} /^\// {print}'
	}
}

fn shuffle-subdirs {|*|
	.d 'Shuffled list of directories in directory'
	.a 'DIRECTORY [FILTER_GLOB]'
	.c 'file'
	let (dir = $*(1); filt = $*(2)) {
		~ $filt () && filt = '*'
		find -L $dir -maxdepth 1 -mindepth 1 -type d -iname $filt \
			|shuf|awk '/^[^/]/ {print "'`pwd'/"$0} /^\// {print}'
	}
}

fn tsview {|*|
	.d 'Typescript viewer'
	.a '[FILE]'
	.a '(none)  # ./typescript'
	.c 'file'
	if {!~ $#* 1} {
		* = ./typescript
	}
	teseq -CLDE $*|reseq - -|col -b|less -FXi
}

fn tvis {|files|
	.d 'Tabbed editor'
	.a 'FILE...'
	.c 'file'
	if {~ $files ()} {
		.usage tvis
	} else if {$#files :gt 20} {
		throw error tvis 'refusing to open more than 20 files'
	} else {let (ggpid; pixgeom; ttag; xewid; tpids) {
		{stq -t getgeom &} >[2]/dev/null
		ggpid = $apid
		pixgeom = `{/usr/bin/xprop \
				-id `{xdotool search --sync --name getgeom} \
			|grep 'specified size:'|cut -d: -f2 \
			|sed 's/ by /x/'|tr -d ' '}
		kill $ggpid
		ttag = tvis-$ggpid
		xewid = `{tabbed -d -c -n $ttag -g $pixgeom >[2]/dev/null}
		for f $files {
			if {access -f -- $f || access -l $f} {
				if {access -r -- $f} {
					if {file $f|grep -q text} {
						{stq -w $xewid -n st-$ggpid \
							-t $f -e vis $f &} \
							>[2]/dev/null
						tpids = $apid $tpids
					} else {
						echo 'tvis: '$^f \
							^': not a text file'
					}
				} else {
					echo 'tvis: '^$f^': not readable'
				}
			} else {
				echo 'tvis: '^$f^': not a text file'
			}
		}
		if {~ $tpids ()} {
			xdotool search --classname $ttag windowkill
			throw error tvis 'no valid files'
		}
		{{
			while {!~ `{xdotool search --classname $ttag} ()} {
				sleep 0.5
			}
			kill $tpids >[2]/dev/null
		} &} >[2]/dev/null
	}}
	true
}

fn unzipd {|*|
	.d 'Unzip into a directory named after the archive'
	.a 'ZIP_FILE'
	.c 'file'
	if {!~ $#* 1} {
		.usage unzipd
	} else {
		let (d = `` \n {basename $* .zip}) {
			mkdir -p $d
			mv $* $d
			unwind-protect {
				cd $d
				unzip $* || true
			} {
				cd ..
			}
		}
	}
}

fn viewcert {|*|
	.d 'View certificate file'
	.a 'FILE'
	.c 'file'
	openssl x509 -text -noout -in $*|less -iRFX
}

fn vman {|*|
	.d 'View man page'
	.a '[man_OPTS] PAGE'
	.c 'file'
	%only-X
	if {~ $#* 0} {
		.usage vman
	} else {
		%with-suffixed-tempfile f .ps {
			/usr/bin/man -Tps $* >$f
			/usr/bin/zathura $f #>/dev/null >[2=1]
		}
	}
}

fn xd {|*|
	.d 'Simple XML dump'
	.a '[FILE]'
	.c 'file'
	if {$#* :gt 1} {
		.usage xd
	} else if {~ $* ()} {
		cat|xmllint --format -
	} else {
		xmllint --format $*
	} | less -iRFXS
}
