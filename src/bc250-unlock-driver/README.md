# bc250-unlock-driver.efi

[Hexxeh/bc250-efi-core-unlock](https://github.com/Hexxeh/bc250-efi-core-unlock) (MIT) at `671936b`, built as an
OpenCore driver instead of a boot application. `main.c.patch` makes the core count selectable: a `6` or `8` in the
driver's Arguments, else `bc250cores=6|8` in boot-args, else 8.

On a cold boot it writes core mask `0xFF` and warm-resets once; on the next pass it applies the SMU firmware patches and
returns to OpenCore.

Build (clang, lld):

    git clone --recursive https://github.com/Hexxeh/bc250-efi-core-unlock
    cd bc250-efi-core-unlock && git checkout 671936b && git submodule update --init
    git apply ../main.c.patch
    python3 gen_patches.py bc250-smu-unlock/bc250_smu/patches.hex patches.data.h
    clang -I. -I yoppeh-efi -DEFI_PLATFORM=1 -target x86_64-unknown-windows -ffreestanding -mno-red-zone -nostdlib \
        -fuse-ld=lld -Wl,-entry:efi_main -Wl,-subsystem:efi_boot_service_driver \
        -o bc250-unlock-driver.efi main.c smu.c unlock.c patches.c

The result matches the shipped binary except for the PE timestamp.
