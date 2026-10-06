# BC-250 Hackintosh OpenCore

OpenCore EFI for the ASRock BC-250 (AMD Cyan Skillfish: 6-core Zen 2 plus an RDNA GPU, 16 GB GDDR6 shared).
OpenCore 1.0.8 RELEASE, macOS Tahoe 26.7.1, MacPro7,1 SMBIOS.

![About This Mac](images/about-this-mac.jpg)

## Status

| | |
|---|---|
| CPU | 6 cores / 12 threads stock, 8 / 16 with the unlock below. Shows as "AMD Cyan Skillfish" |
| GPU | Metal 3 with [MetalCyan](https://github.com/amethyst8118/MetalCyan). 24 CUs stock, 40 with `bc250cu=40` |
| VRAM | 4 GB (BIOS setting below) |
| Ethernet | Works (RealtekRTL8111) |
| NVMe | Works |
| USB | USB 2.0 ports only. Not mapped yet, XHCI0 has to be off in the BIOS. See [USB](#usb) |
| Audio | None. No HDMI/DP audio yet, and the board has no analog codec |
| Video decode | Software only (VCN isn't usable on this chip) |
| Sleep | Not tested |

## Get started

> [!IMPORTANT]
> This EFI is for **macOS Tahoe 26.7.1** with the **MacPro7,1** SMBIOS only. The kernel patches and MetalCyan are
> matched to that exact build. Other macOS versions and other SMBIOS models aren't supported and may not boot.

### BIOS

- **UMA frame buffer size: 4 GB.** With the default 512 MB the GPU runs out of VRAM and the screen freezes green.
- **IOMMU: Disabled.**
- **XHCI0: Disabled.** The ports on XHCI0 (the USB 3.0 ports) stop working, so plug the keyboard, mouse and USB
  stick into the USB 2.0 ports. See [USB](#usb) for trying it enabled.

### SMBIOS

Generate a **MacPro7,1** serial, MLB, UUID and ROM (GenSMBIOS) and put them in `PlatformInfo > Generic`. They're left
empty here.

## Boot-args

The default is just `npci=0x3000`. Add `-MCOff` to boot without GPU acceleration (plain framebuffer), for example
to rule MetalCyan out when something breaks.

Everything else is opt-in and per board. These come from MetalCyan and talk to the SMU directly:

| Boot-arg | Range | |
|---|---|---|
| `bc250cu=40` | | All 40 CUs instead of 24. More heat and power draw |
| `bc250gfxmhz=N` | 350-2000 MHz | GPU clock. Anything above 2000 makes the SMU firmware stop responding, so it's ignored |
| `bc250gfxmv=N` | 700-1100 mV | GPU voltage, used with `bc250gfxmhz`. Can't go more than 50 mV under the stock curve |
| `bc250cpumhz=N` | 3500-4500 MHz | CPU boost clock. Comes with an undervolt worked out from `bc250cpuvmax` |
| `bc250cpuvmax=N` | 950-1325 mV | CPU voltage ceiling (default 1275) |
| `bc250cputemp=N` | 50-100 °C | CPU temperature limit (default 90 with `bc250cpumhz`) |
| `bc250gputemp=N` | 50-100 °C | GPU temperature where the forced GPU clock is let go (default 90) |
| `bc250smu=0` | | No SMU access at all |

The clocks are applied 60 seconds after boot, so a setting that's too much never stops the machine from booting.
You can always reach the desktop and remove it. If the SMU gets stuck (telemetry frozen, CPU stuck at one clock),
take the setting out and power off for 10 seconds; a restart doesn't reset it.

What this board runs, with 8 cores:

    npci=0x3000 bc250cu=40 bc250gfxmhz=2000 bc250gfxmv=1080 bc250cpumhz=4000 bc250cpuvmax=1300

![AMD Power Gadget, 8 cores at 4 GHz](images/amd-power-gadget.jpg)

## 8 cores

The BC-250 has 8 Zen 2 cores with 2 fused off by a core mask the SMU can change. `Drivers/bc250-unlock-driver.efi`
changes it before macOS loads. It's off by default. To turn it on:

1. Enable `bc250-unlock-driver.efi` in `UEFI > Drivers`.
2. In `Kernel > Patch`, change the four `algrey | Force cpuid_cores_per_package` patches from 6 to 8 cores: the
   second byte of `Replace` goes from `06` to `08` (`B8 06` / `BA 06` become `B8 08` / `BA 08`).

On a cold boot the driver unlocks the cores and warm-resets once, so you'll see one extra POST. After that every boot,
cold or warm, comes up with 8 cores / 16 threads. A board whose core mask isn't the stock one is left alone. The
driver also writes rw-r-r-0644's SMU firmware patches on every boot. To go back to 6, disable the driver, set the
patches back to `06` and power off once.

The driver is [Hexxeh/bc250-efi-core-unlock](https://github.com/Hexxeh/bc250-efi-core-unlock) built as an OpenCore
driver. Source patch and build steps are in `src/bc250-unlock-driver`.

## USB

The rear I/O is 4 ports (2x USB 3.0, 2x USB 2.0) with no internal headers. The FCH carries one XHCI (1022:7814 at
00:10.0: 2 USB 2 + 2 USB 3 ports) and two EHCI (1022:7808 at 00:12.2 and 00:13.2) with OHCI companions (1022:7807 at
00:12.0/00:13.0, 1022:7809 at 00:14.5), per the [linux-hardware.org probe](http://linux-hardware.org/?probe=1cf286ab87).

`UTBDefault.kext` attaches USBToolBox to every USB controller without a map, so every port macOS can see already
works: 4 ports never reach the 15-port limit. A map would only add connector types. The USB 3.0 ports are dead because
XHCI0 is off in the BIOS, not because they aren't mapped.

Caveat, not verified on this board: macOS dropped its OHCI driver in Ventura (EHCI stays). Full- and low-speed
devices, which includes most 2.4 GHz mouse/keyboard receivers (12 Mbps), are handed to an OHCI companion on the EHCI
ports and may not show up in macOS. Linux shows where a device lands: in `lsusb -t`, a receiver under `ohci-pci` at
`12M` won't work on that port in macOS. On the XHCI ports every speed is handled by the XHCI itself.

The BC-250 doesn't boot Windows, so USBToolBox's recommended Windows route isn't available. To get the USB 3.0 ports:

1. In Linux, record the baseline: `lspci -nn | grep -i usb` and `lspci -vvv -s 00:10.0` (check the MSI capability),
   `dmesg | grep -i -E 'xhci|handoff'`, then `lsusb -t` with a USB 2 and a USB 3 device plugged into each port in
   turn.
2. Enable XHCI0 in the BIOS and boot macOS with `-v`.
3. If it boots but the USB 3.0 ports stay dead, check for a failed ownership handoff: Apple's driver does the handoff
   itself but gives the firmware only 100 ms and then gives up, unlike Linux. Look for
   `unable to obtain controller ownership from BIOS` with
   `log show --last boot --predicate 'process == "kernel"' | grep -i -E 'xhci|ownership'`; if it is there, set
   `UEFI > Quirks > ReleaseUsbOwnership` to true and retry. If the message persists, also enable the disabled
   `Kernel > Patch` entry `AppleUSBXHCI: BIOS handoff timeout 100 ms -> 1000 ms` (26.x only; it gives the firmware
   1 s like Linux; it does not force anything, the driver still fails cleanly if the firmware never lets go).
   It was checked against 26.7.1's AppleUSBXHCI (exactly one match).
4. If it hangs at boot, photograph the last lines and turn XHCI0 off again.
5. Once it works, the USB 3.0 ports already work through `UTBDefault.kext`. To map them anyway, run the macOS version
   of the [USBToolBox tool](https://github.com/USBToolBox/tool) (its port-limit problems don't apply to 4 ports):
   plug a USB 2 and a USB 3 device into every port, build `UTBMap.kext`, add it to `config.plist` under
   `Kernel > Add` after `USBToolBox.kext`, and remove `UTBDefault.kext` (its entry and folder).
6. Keep `XhciPortLimit` off. It has been broken since macOS 11.3 (per USBToolBox's README).

Wireless Razer/Logitech receivers work as plain USB HID. Razer Synapse for Mac only runs on Apple silicon, so set
DPI/RGB/macros on another PC and save them to the device's onboard memory if it has it.

## What's in it

- **Kexts:** Lilu, RestrictEvents (CPU name), VirtualSMC, AMDRyzenCPUPowerManagement + SMCAMDProcessor, NVMeFix,
  AppleMCEReporterDisabler, RealtekRTL8111, USBToolBox + UTBDefault, MetalCyan 1.0.1.
- **Kernel patches:** AMD_Vanilla, with the 26.4+ fixes from AMD_Vanilla PR
  [#215](https://github.com/AMD-OSX/AMD_Vanilla/pull/215), plus one more for Tahoe. The BC-250 reports CPUID model
  0x47, which Tahoe takes for an Intel Broadwell and starts XCPM on; the `_xcpm_bootstrap` patch forces it off.
  Also included, disabled: an `AppleUSBXHCI` handoff-timeout patch (100 ms -> 1000 ms, 26.x only); see [USB](#usb).
- **CPU name:** set with RestrictEvents' `revcpuname` (NVRAM `4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102`).
- **Drivers:** OpenRuntime, HfsPlus, ResetNvramEntry, bc250-unlock-driver (disabled).

## Known issues

- **No HDMI/DP audio.** Safari and the TV app won't play video without an audio output device. A virtual one
  (BlackHole etc.) works around it.
- **USB isn't mapped.** XHCI0 is off in the BIOS and only the USB 2.0 ports are used. See [USB](#usb).
- **Panic at shutdown/restart.** WindowServer panics while the display goes down (`IOAccelDisplayMachine::
  display_mode_did_change: AMDRadeonAccelerator driver returns false`). The next boot is fine.
- **No GPU recovery.** If the GPU ever hangs, the screen freezes until a reboot (Navi 10's reset hangs this GPU, so it
  is blocked).
- **Sleep** hasn't been tried.

GPU-side details are in the [MetalCyan README](https://github.com/amethyst8118/MetalCyan).

## Credits

Acidanthera (OpenCore, Lilu, VirtualSMC, NVMeFix, RestrictEvents), AMD-OSX (AMD_Vanilla) and laobamac (PR #215),
trulyspinach (SMCAMDProcessor, AMD Power Gadget), USBToolBox, Mieze (RealtekRTL8111), ChefKiss (NootedRed, which
MetalCyan is based on).

BC-250 tooling the core unlock and MetalCyan's SMU code build on:

- [Hexxeh/bc250-efi-core-unlock](https://github.com/Hexxeh/bc250-efi-core-unlock): the unlock driver
- [rw-r-r-0644/bc250-core-unlock](https://github.com/rw-r-r-0644/bc250-core-unlock) and
  [rw-r-r-0644/bc250-smu-unlock](https://github.com/rw-r-r-0644/bc250-smu-unlock): core unlock and SMU firmware patches
- [bc250-collective/bc250_smu_oc](https://github.com/bc250-collective/bc250_smu_oc): SMU mailbox and CPU overclocking
- [duggasco/bc250-40cu-unlock](https://github.com/duggasco/bc250-40cu-unlock): 40 CU unlock

Not responsible for what happens to your board, especially with the overclocking options.
