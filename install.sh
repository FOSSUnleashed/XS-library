#! /bin/sh

if [ ! -w /etc ]; then
	echo $USER can not write /etc
	exit 1
fi
sudo install -v -m 755 -d /etc/xs/rc.d /etc/xs/lib.d
for f in xs/rc.d/*; do
	sudo install -v -b -C -m 644 $f /etc/xs/rc.d/
done
for f in xs/lib.d/*; do
	sudo install -v -b -C -m 644 $f /etc/xs/lib.d/
done
