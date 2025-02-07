#!/usr/bin/env bash

# kill previous x11 sockets that have persisted
rm -r /tmp/.X11-unix 2>/dev/null

### This block of code is the a slightly modified base entry.sh
### that uses the udev service instead of try to start things
### directly. That method does _not_ allow plug-and-play to
### actually work.  Code grab ends at '### entry.sh grb end'.

# This command only works in privileged container
tmp_mount='/tmp/_balena'
mkdir -p "$tmp_mount"
if mount -t devtmpfs none "$tmp_mount" &> /dev/null; then
	PRIVILEGED=true
	umount "$tmp_mount"
else
	PRIVILEGED=false
fi
rm -rf "$tmp_mount"

function mount_dev()
{
	tmp_dir='/tmp/tmpmount'
	mkdir -p "$tmp_dir"
	mount -t devtmpfs none "$tmp_dir"
	mkdir -p "$tmp_dir/shm"
	mount --move /dev/shm "$tmp_dir/shm"
	mkdir -p "$tmp_dir/mqueue"
	mount --move /dev/mqueue "$tmp_dir/mqueue"
	mkdir -p "$tmp_dir/pts"
	mount --move /dev/pts "$tmp_dir/pts"
	touch "$tmp_dir/console"
	mount --move /dev/console "$tmp_dir/console"
	umount /dev || true
	mount --move "$tmp_dir" /dev

	# Since the devpts is mounted with -o newinstance by Docker, we need to make
	# /dev/ptmx point to its ptmx.
	# ref: https://www.kernel.org/doc/Documentation/filesystems/devpts.txt
	ln -sf /dev/pts/ptmx /dev/ptmx

	# When using io.balena.features.sysfs the mount point will already exist
	# we need to check the mountpoint first.
	sysfs_dir='/sys/kernel/debug'

	if ! mountpoint -q "$sysfs_dir"; then
		mount -t debugfs nodev "$sysfs_dir"
	fi

}

function start_udev()
{
	if [ "$UDEV" == "on" ]; then
		if $PRIVILEGED; then
		        mount_dev
                        service udev start
		else
			echo "Unable to start udev, container must be run in privileged mode to start udev!"
		fi
                udevadm trigger
	fi
}

function init()
{
	# echo error message, when executable file is passed but doesn't exist.
	if [ -n "$1" ]; then
		if CMD=$(command -v "$1" 2>/dev/null); then
			shift
			exec "$CMD" "$@"
		else
			echo "Command not found: $1"
			exit 1
		fi
	fi
}

UDEV=$(echo "$UDEV" | awk '{print tolower($0)}')

case "$UDEV" in
	'1' | 'true')
		UDEV='on'
	;;
esac

start_udev
init "$@"
### entry.sh grb end'.


echo "Setting initial display to FORCE_DISPLAY - $FORCE_DISPLAY"

# destroy any leftover X11 lockfile. credit to @danclimasevschi
# https://github.com/balena-labs-projects/xserver/issues/16
DISP_NUM=$(echo "$FORCE_DISPLAY" | sed "s/://")
LOCK_FILE="/tmp/.X${DISP_NUM}-lock"
if [ -f "$LOCK_FILE" ]; then
    echo "Removing lockfile $LOCK_FILE"
    rm -f "$LOCK_FILE" &> /dev/null
fi

export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket

echo "balenaLabs xserver version: $(cat VERSION)"

# If the vcgencmd is supported (i.e. RPi device) - check enough GPU memory is allocated
if command -v vcgencmd &> /dev/null
then
	echo "Checking GPU memory"
    if [ "$(vcgencmd get_mem gpu | grep -o '[0-9]\+')" -lt 128 ]
	then
	echo -e "\033[91mWARNING: GPU MEMORY TOO LOW"
	fi
fi

while true; do
if [ "$CURSOR" = true ];
then
    exec startx -- $FORCE_DISPLAY
else
    exec startx -- $FORCE_DISPLAY -nocursor
fi
sleep 10
done
