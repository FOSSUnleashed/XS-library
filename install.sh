#! /bin/sh

echo sudo install -m 755 -d /etc/xs/rc.d /etc/xs/lib.d
for f in xs/rc.d/*; do
	echo sudo install -m 644 $f /etc/xs/rc.d/
done
for f in xs/lib.d/*; do
	echo sudo install -m 644 $f /etc/xs/lib.d/
done
