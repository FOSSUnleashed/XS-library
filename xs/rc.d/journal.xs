fn journal {|*|
	.d 'Secure journal'
	.c 'file'
	%with-terminal journal {
	let (ufile = ~/.journal; cfile) {
		%with-tempfile kf {
			printf 'Passphrase? '
			%without-echo {printf %s\n <=read >$kf}
			echo
			cfile = $ufile^.nc
			access -f $cfile || {
				%with-tempfile kc {
					printf 'Confirm passphrase? '
					%without-echo {
						printf %s\n <=read >$kc
					}
					echo
					cmp -s $kf $kc || \
						throw error journal \
							'passphrases differ'
				}
			}
			access -f $ufile && access -f $cfile && {
				throw error journal 'inconsistent'
				ls -l $ufile $cfile
			}
			access -f $cfile && {
				mdecrypt -q -f $kf -u $cfile || \
					throw error journal 'decryption failed'
			}
			access -f $ufile || touch $ufile
			unwind-protect {
				vis $ufile
			} {
				mcrypt -q -f $kf -u $ufile
			}
		}
	}
	}
}
