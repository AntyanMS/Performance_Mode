#!/bin/sh
# Chuwi / USB Bluetooth: после S3 стек иногда «молчит», пока не поднять USB-питание и bluetoothd.
# Устанавливается install.sh в /usr/lib/systemd/system-sleep/

case "$1" in
	post)
		dev=""
		if [ -e /sys/class/bluetooth/hci0/device ]; then
			dev=$(readlink -f /sys/class/bluetooth/hci0/device)
		fi
		while [ -n "$dev" ] && [ "$dev" != "/" ]; do
			if [ -f "$dev/idVendor" ] && [ -w "$dev/power/control" ]; then
				echo on >"$dev/power/control" 2>/dev/null || true
				break
			fi
			dev=$(dirname "$dev")
		done
		if systemctl is-active --quiet bluetooth; then
			systemctl restart bluetooth
		fi
		;;
esac
