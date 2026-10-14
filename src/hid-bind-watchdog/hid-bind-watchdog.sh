#!/bin/sh
# hid-bind-watchdog: recover a USB keyboard/mouse that enumerated at boot but never became a HID device.
#
# Seen on this board: a keyboard enumerates on USB, Apple's DriverKit HID driver claims its interfaces
# (UsbExclusiveOwner=AppleUserUSBHostHIDDevice), but no IOHIDDevice is ever created, so the keyboard is dead
# until replugged. Restarting the HID driver server makes DriverKit respawn it and every USB HID device
# re-binds (measured: ~2 s). This script checks once a minute; if a USB HID device has had no IOHIDDevice
# for over 90 s it restarts that server, at most twice per boot.
#
# Opt-in: install with the LaunchDaemon in this directory (see README.md). Uninstalling it changes nothing else.

PATH=/usr/bin:/bin:/usr/sbin:/sbin
STATE=/var/tmp/com.bc250.hid-bind-watchdog.state
GRACE_S=90
MAX_RESTARTS=2

log() {
    echo "hid-bind-watchdog: $*"
    logger -t hid-bind-watchdog "$*" 2>/dev/null
}

# locationIDs (hex, no 0x) of USB devices with a HID-class interface. Interface blocks in the registry
# dump follow their device, so the last locationID seen belongs to the right device.
usb_hid_locs() {
    ioreg -c IOUSBHostInterface -w0 -l 2>/dev/null | awk '
        /"locationID" = [0-9]/ { loc=sprintf("%x", $NF) }
        /"bInterfaceClass" = 3/ && loc != "" { print loc }
    ' | sort -u
}
hid_locs() {
    hidutil list 2>/dev/null | awk '/^0x/ { print tolower(substr($3, 3)) }' | sort -u
}

boot_token() { sysctl -n kern.boottime 2>/dev/null; }

now=$(date +%s)
boot=$(boot_token)

restarts=0
since=0
if [ -f "$STATE" ]; then
    # shellcheck disable=SC1090
    . "$STATE" 2>/dev/null
    [ "$SAVED_BOOT" = "$boot" ] || { restarts=0; since=0; }
fi

save_state() {
    printf 'SAVED_BOOT=%s\nrestarts=%s\nsince=%s\n' "'$boot'" "$restarts" "$since" > "$STATE" 2>/dev/null
}

USB_TMP=$(mktemp /tmp/hidwatch.usb.XXXXXX) || exit 0
HID_TMP=$(mktemp /tmp/hidwatch.hid.XXXXXX) || exit 0
trap 'rm -f "$USB_TMP" "$HID_TMP"' EXIT

usb_hid_locs > "$USB_TMP"
hid_locs > "$HID_TMP"
missing=$(comm -23 "$USB_TMP" "$HID_TMP")
if [ -n "$WATCHDOG_DEBUG" ]; then
    echo "usb-hid: $(tr '\n' ' ' < "$USB_TMP")"
    echo "hid:     $(tr '\n' ' ' < "$HID_TMP")"
    echo "missing: $(echo $missing)"
fi

if [ -z "$missing" ]; then
    [ "$since" != "0" ] && { since=0; save_state; }
    exit 0
fi

# A device can legitimately take a few seconds to bind; only act on a persistent miss.
if [ "$since" = "0" ]; then
    since=$now
    save_state
    log "USB HID device(s) without a HID device: $(echo $missing); watching for ${GRACE_S}s"
    exit 0
fi

if [ $((now - since)) -lt $GRACE_S ] || [ "$restarts" -ge $MAX_RESTARTS ]; then
    exit 0
fi

pid=$(pgrep -f 'com.apple.AppleUserHIDDrivers' | head -n 1)
if [ -n "$pid" ]; then
    log "USB HID device(s) still unbound after $((now - since))s: $(echo $missing); restarting HID driver server (pid $pid)"
    kill "$pid" 2>/dev/null
    restarts=$((restarts + 1))
    since=$now
    save_state
fi
exit 0
