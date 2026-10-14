# USB HID bind watchdog (optional)

Once, a USB keyboard on this board was dead after boot even though it was plugged in the whole time:

- The keyboard enumerated on USB (SEMITEK "USB-HID Gaming Keyboard", XHC0 port 4) and Apple's DriverKit
  HID driver claimed all three of its interfaces (`UsbExclusiveOwner` = `AppleUserUSBHostHIDDevice`).
- But no `IOHIDDevice` was ever created — `hidutil list` had no entry for it — so macOS received no
  keystrokes. That boot-time enumeration took 3,183 ms; the bind had stalled.
- Unplugging and replugging the keyboard fixed it (46 ms enumeration, HID device appeared). Restarting
  the HID driver server also fixes it without touching the cable: DriverKit respawns it and every USB
  HID device re-binds (measured at ~2 s for a keyboard and a Logitech receiver).

The root cause is inside Apple's DriverKit HID stack, not in this EFI, so the fix here is recovery, not
prevention: a small root LaunchDaemon checks once a minute whether any USB device with a HID interface
still has no HID device after 90 s, and if so restarts the HID driver server (at most twice per boot).
It only kills that one server process; input from all USB HID devices drops for the ~2 s it takes to
come back, instead of staying dead until someone replugs.

## Install

```sh
sudo install -m 755 hid-bind-watchdog.sh /usr/local/bin/
sudo install -m 644 com.bc250.hid-bind-watchdog.plist /Library/LaunchDaemons/
sudo launchctl bootstrap system /Library/LaunchDaemons/com.bc250.hid-bind-watchdog.plist
```

## Uninstall

```sh
sudo launchctl bootout system/com.bc250.hid-bind-watchdog
sudo rm /Library/LaunchDaemons/com.bc250.hid-bind-watchdog.plist /usr/local/bin/hid-bind-watchdog.sh
```

## Notes

- Check what it sees without installing: `WATCHDOG_DEBUG=1 sh hid-bind-watchdog.sh` prints the USB-HID
  and HID locationID sets and what it thinks is missing.
- It logs to `/var/log/hid-bind-watchdog.log` and the unified log (`logger`, tag `hid-bind-watchdog`).
- Bluetooth HID devices are not compared (different transport); only USB devices with a HID-class
  interface are watched.
- If no USB HID device is missing, the script exits in a couple of seconds and changes nothing.
