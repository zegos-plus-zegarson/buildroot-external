# ZegOS: chiliBoard Premium

chiliSOM Premium: AM3352 at 600 MHz, 128 MB DDR3, 256 MB NAND.

| Component | Version |
| --- | --- |
| Buildroot | 2026.08.x |
| Linux | 6.12.6 |
| U-Boot | 2024.10 |
| Toolchain | Bootlin ARMv7 hard-float glibc stable (x86_64 host) |

## Build

From `buildroot-external`, clone Buildroot beside it if needed:

```sh
git clone --depth 1 --branch 2026.08.x https://gitlab.com/buildroot.org/buildroot.git ../buildroot
docker compose build
docker compose run --rm ubuntu-buildroot make zegos_chiliboard_defconfig
docker compose run --rm ubuntu-buildroot sh -c 'make -j"$(nproc)"'
```

If `../buildroot/output` was built with another toolchain, run
`docker compose run --rm ubuntu-buildroot make clean` before configuring.

Images: `../buildroot/output/images/sdcard.img` (sparse) and
`sdcard.img.bmap`. The disk image has a 16 MiB FAT boot partition and a
128 MiB ext4 root partition; it fits an 8 GB microSD card.

## Flash

Set `SD_DEVICE` to the **whole card device**:

```sh
SD_DEVICE=/dev/sdX
docker run --rm --device="$SD_DEVICE" \
    -v "$(cd ../buildroot && pwd)/output/images:/images:ro" \
    ubuntu-buildroot/frankoslaw:v1.0.5 \
    bmaptool copy --bmap /images/sdcard.img.bmap /images/sdcard.img "$SD_DEVICE"
```

## Boot

Serial console: 115200 8N1 through the micro USB debug port. U-Boot
includes `tftpboot` and keeps the board's USB Type A port in host mode.
The micro USB port is connected to a USB-to-serial adapter and cannot
be used for USB fastboot.
