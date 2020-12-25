fn podman-latest {|*|
	.d 'Print IMAGE ID of most recently-created Podman image'
	.a '[-q]  # Suppress image details to stderr'
	.c 'system'
	.r 'pps podman-run podman-run-X'
	let (id = `{podman images -q|head -1}) {
		if {!~ $id () && !~ $* -q} {
			podman images --format '{{.ID}}'\t'{{.Repository}}' \
				^\t'{{.Tag}}'\t'{{.Created}}' \
				| grep \^$id \
				| column -t -N ID,Repository,Tag,Created \
				>[1=2]
			printf 'Labels ' >[1=2]
			podman inspect $id | jq -M '.[]|.Config|.Labels' >[1=2]
		}
		echo $id
	}
}

fn pps {|*|
	.d 'Podman ps'
	.a '[-l]  # show labels'
	.c 'system'
	.r 'podman-latest podman-run podman-run-X'
	let (fmt = '{{.ID}} {{.Image}} {{.Names}} {{.Command}}' \
	^' "{{.Status}}"') {
		~ $* -l && fmt = $fmt^' "{{.Labels}}"'
		podman ps --format $fmt |grep -v '^$' \
			|| echo 'No Podman containers' >[1=2]
	}
}

fn podman-run {|*|
	.d 'Run Podman image'
	.a '[podman_run-OPTIONS] IMAGE_ID'
	.c 'system'
	.r 'podman-latest pps podman-run-X'
	if {~ $* ()} {
		.usage podman-run
	} else {
		podman run --rm -it $*
	}
}

fn podman-run-X {|*|
	.d 'Run Podman image with access to host X display'
	.a '[podman_run-OPTIONS] IMAGE_ID'
	.c 'system'
	.r 'podman-latest pps podman-run'
	if {~ $* ()} {
		.usage podman-run-X
	} else {
		podman run --rm -it -e DISPLAY \
			-v /tmp/.X11-unix:/tmp/.X11-unix \
			-v $HOME/.Xauthority:$HOME/.Xauthority \
			--net=host --pid=host --ipc=host $*
	}
}
