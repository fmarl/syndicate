# Syndicate
Syndicate is a BIOS bootloader. It loads a stage 2 and a kernel from a
FAT32 partition and jumps to the stage 2.

The kernel is loaded as is. Parsing it and switching to protected or long
mode is up to the stage 2, so any kernel can be booted with a matching stage 2.

## Requirements
- BIOS with INT 13h extensions
- MBR partition table, the first partition is FAT32 (type `0x0B` or `0x0C`)
  with 512 byte sectors and starts after `loader.bin`, e.g. at sector 2048
- stage 2 and kernel in the root directory

## Boot protocol
| File          | Default      | Address   | Max size |
|---------------|--------------|-----------|----------|
| `STAGE2_FILE` | `STAGE2.BIN` | `0x01000` | 24 KiB   |
| `KERNEL_FILE` | `KERNEL.BIN` | `0x10000` | 512 KiB  |

Stage 2 is entered at `0x0100:0x0000` in real mode with A20 enabled,
`DL` = boot drive and `ECX` = kernel size.

## Build
Requires `nasm` and GNU make. On Guix, `guix shell -m manifest.scm`
provides everything including the test tools.

    make
    make STAGE2_FILE=KERNEL.BIN KERNEL_FILE=HADRON.ELF

## Install
The first 446 bytes go into the MBR, the rest into the following sectors:

    dd if=loader.bin of=/dev/XXX bs=446 count=1 conv=notrunc
    dd if=loader.bin of=/dev/XXX bs=512 skip=1 seek=1 conv=notrunc

## Testing
`make image` creates a 64 MiB disk image (requires `sfdisk` and `mtools`),
`make run` boots it in QEMU:

    make run STAGE2=path/to/stage2.bin KERNEL=path/to/kernel
