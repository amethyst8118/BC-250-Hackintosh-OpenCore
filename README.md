# BC-250 Hackintosh OpenCore

OpenCore EFI for the ASRock BC-250 (AMD Cyan Skillfish: Zen 2 CPU, RDNA GPU, 16 GB GDDR6). OpenCore 1.0.8,
tested on macOS Tahoe 26.7.1.

| | |
|---|---|
| CPU | 8 cores / 16 threads (the two disabled cores are enabled before boot) |
| GPU | Metal 3 with [MetalCyan](https://github.com/amethyst8118/MetalCyan) |
| Ethernet, NVMe, USB | Working |
| Audio | No (no HDMI/DP audio yet). Safari and the TV app need an audio device to play video |
| Sleep | Not tested |

## Before you boot

- BIOS: set the UMA frame buffer (VRAM) to 4 GB. With 512 MB the GPU runs out of memory and the screen freezes green.
- BIOS: disable XHCI0 and use the USB 2.0 ports.
- Generate a MacPro7,1 serial, MLB, UUID and ROM (GenSMBIOS) and fill them in under PlatformInfo > Generic.

## Boot-args

Default: `npci=0x3000`. Add `-MCOff` to boot without MetalCyan (firmware framebuffer, no acceleration).

Optional, per board (tested on one board; start lower and check temperatures):

| | |
|---|---|
| `bc250cu=40` | Enable all 40 CUs (stock 24) |
| `bc250gfxmhz=2000 bc250gfxmv=1080` | GPU clock and voltage (max 2000 MHz) |
| `bc250cpumhz=4000 bc250cpuvmax=1300` | CPU boost clock and voltage ceiling (max 1325 mV) |
| `bc250cores=6` | Keep the stock 6 cores |

## What's in it

- `Drivers/bc250-unlock-driver.efi`: enables the two fused-off cores before macOS loads (source in
  `src/bc250-unlock-driver`). The AMD_Vanilla core-count patches are set to 8 to match.
- Kernel patches: AMD_Vanilla, plus one for Tahoe: `_xcpm_bootstrap` forces XCPM off (the BC-250 reports CPUID model
  0x47, which Tahoe treats as Intel Broadwell).
- Kexts: Lilu, VirtualSMC, MetalCyan, AMDRyzenCPUPowerManagement + SMCAMDProcessor, NVMeFix, RealtekRTL8111,
  USBToolBox + UTBDefault, AppleMCEReporterDisabler.

## Credits

Acidanthera (OpenCore, Lilu, VirtualSMC, NVMeFix), AMD-OSX (AMD_Vanilla), trulyspinach (SMCAMDProcessor), USBToolBox,
Mieze (RealtekRTL8111), rw-r-r-0644 and Hexxeh (core unlock), ChefKiss (NootedRed, which MetalCyan is based on).

Not responsible for damage to your board, especially from the overclocking options.
