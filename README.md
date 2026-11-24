# ZegOS: chiliBoard Premium

Tested board: AM3352, 256 MiB RAM, 256 MiB NAND.

| Component | Version |
| --- | --- |
| Buildroot | 2026.08.x |
| Linux | 6.12.6 |
| U-Boot | 2024.10 |
| Toolchain | Bootlin ARMv7 hard-float glibc stable (x86_64 host) |

## QEMU ARM Vexpress: SD A/B and recovery

`zegos_qemu_arm_vexpress_defconfig` runs U-Boot and Linux on QEMU's
`vexpress-a9` machine. It mirrors the current chiliBoard SD layout: U-Boot
boots rootfs A, rootfs B is an initial copy, and a separate recovery rootfs
is tried if A cannot be loaded. The emulator uses one SD disk.

```sh
docker compose run --rm ubuntu-buildroot make O=output-qemu-arm-vexpress zegos_qemu_arm_vexpress_defconfig
docker compose run --rm ubuntu-buildroot sh -c 'make O=output-qemu-arm-vexpress -j"$(nproc)"'
./scripts/run-qemu-arm-vexpress.sh
```

The launcher reads `output-qemu-arm-vexpress/images` and keeps a writable
copy of `disk.img` under `.qemu-arm-vexpress/`. Pass another images directory
as its first argument, or set `QEMU_STATE_DIR` for another writable disk
location. Set `QEMU_RESET_DISK=1` for one launch to copy the freshly built
disk again. Press Ctrl-A, X to exit QEMU. The login prompt uses `ttyAMA0`.

| Partition | Size | Purpose |
| --- | ---: | --- |
| `/dev/mmcblk0p1` | 16 MiB | FAT boot script, kernel, DTB |
| `/dev/mmcblk0p2` | 256 MiB | Rootfs A, current boot target |
| `/dev/mmcblk0p3` | 256 MiB | Rootfs B, initial copy of A |
| `/dev/mmcblk0p4` | 256 MiB | Recovery rootfs with its own kernel and DTB |
| `/dev/mmcblk0p5` | 128 MiB | Shared test data, mounted at `/data` |

The boot script tries A and then recovery. U-Boot also tries recovery if
`boot.scr` is unavailable. A kernel that starts and later fails cannot be
detected by this U-Boot script. Slot switching can be added after the basic
image is validated.

## SD card (4 GB)

### Build

From `buildroot-external`, clone Buildroot beside it if needed:

```sh
git clone --depth 1 --branch 2026.08.x https://gitlab.com/buildroot.org/buildroot.git ../buildroot
docker compose build
docker compose run --rm ubuntu-buildroot make O=output-sd-4gb zegos_chiliboard_sd_4gb_defconfig
docker compose run --rm ubuntu-buildroot sh -c 'make O=output-sd-4gb -j"$(nproc)"'
```

Keep separate output directories for SD, NAND, and NFS. If an output directory
was built with another toolchain, clean that output before reconfiguring it.

Output: `../buildroot/output-sd-4gb/images/sdcard.img` (sparse) and
`sdcard.img.bmap`. The MBR image targets a nominal 4 GB microSD card:

| Partition | Size | Contents |
| --- | ---: | --- |
| 1: boot | 16 MiB | MLO, U-Boot, kernel, DTB, `boot.scr` |
| 2: rootfs A | 1430 MiB (~1.5 GB) | Booted ext4 root filesystem |
| 3: rootfs B | 1430 MiB (~1.5 GB) | Initial copy of A; no slot switch yet |
| 4: userdata | 925 MiB (~0.97 GB) | Empty ext4 filesystem |

Check the card's actual capacity before flashing. Both root partitions are
populated, but U-Boot boots only partition 2. The post-image script generates
`boot.scr` from `board/chiliboard/boot-fallback.cmd` and includes it in the
boot partition.

### Flash

Set `SD_DEVICE` to the **whole card device**:

```sh
SD_DEVICE=/dev/sdX
docker run --rm --device="$SD_DEVICE" \
    -v "$(cd ../buildroot && pwd)/output-sd-4gb/images:/images:ro" \
    ubuntu-buildroot/frankoslaw:v1.0.5 \
    bmaptool copy --bmap /images/sdcard.img.bmap /images/sdcard.img "$SD_DEVICE"
```

### Boot

Select SD boot and power cycle. U-Boot loads `boot.scr` from partition 1; the
script tries TFTP/NFS, SD rootfs A, then NAND recovery. If every target fails,
it prints an error and returns to the U-Boot prompt.

## Serial console

Serial console: 115200 8N1 through the micro USB debug port.
Run `./scripts/serial-console.sh` to open `/dev/ttyUSB0` with picocom and
reconnect when the device appears again.

## NAND recovery (256 MiB)

The NAND variant installs a recovery system in on-board NAND. Its compiled
U-Boot command tries TFTP/NFS, SD slot A, then NAND recovery. The NAND
installer is an SD card image used to program NAND; it has no SD root
filesystem.

### Build

Use a separate output directory:

```sh
docker compose run --rm ubuntu-buildroot make O=output-nand zegos_chiliboard_nand_defconfig
docker compose run --rm ubuntu-buildroot sh -c 'make O=output-nand -j"$(nproc)"'
```

Output: `../buildroot/output-nand/images/nand-installer.img`. The installer
contains a 16 MiB FAT boot partition with `MLO`, `u-boot.img`, and
`flash-nand.scr`, plus a FAT32 payload partition with the DTB, kernel, and
`rootfs.ubi` under `nand/`. The image-generation script checks that each
artifact fits its NAND partition; `rootfs.ubi` is limited to 240 MiB.

### NAND layout

| Offset | Size | MTD partition | Contents |
| ---: | ---: | --- | --- |
| 0x000000 | 4 × 128 KiB | `NAND.SPL` and backups 1–3 | SPL copies |
| 0x080000 | 256 KiB | `NAND.u-boot-spl-os` | Device tree |
| 0x0c0000 | 1 MiB | `NAND.u-boot` | U-Boot |
| 0x1c0000 | 2 × 128 KiB | `NAND.u-boot-env` and backup 1 | Redundant environment |
| 0x200000 | 8 MiB | `NAND.kernel` | Kernel |
| 0xa00000 | 246 MiB | `NAND.file-system` | UBI/UBIFS recovery root |

These offsets match the chiliBoard U-Boot partition map and the NAND Linux
device tree. The UBI image uses a 128 KiB eraseblock, 2 KiB page, 512-byte
subpage, and 129024-byte logical eraseblock. The U-Boot build includes the
SPL NAND page-size fix needed to load U-Boot from NAND.

### Install

Flash the installer image to a **whole SD card device**. This overwrites the
card:

```sh
sudo dd if=../buildroot/output-nand/images/nand-installer.img of=/dev/sdX bs=4M conv=fsync status=progress
```

Insert the card, select SD boot, power cycle, and interrupt U-Boot. At the
U-Boot prompt:

```text
load mmc 0:1 0x81000000 flash-nand.scr
source 0x81000000
```

`flash-nand.scr` checks its inputs, writes the bootloader, DTB, kernel, and
UBI image through U-Boot's NAND driver, then erases both environment copies.
The UBI write uses `nand write.trimffs` so trailing erased pages remain
unwritten. It prints `[FLASH] NAND recovery written` on success. Do not write
the installer image directly to NAND.

### Boot and validation

Remove the installer card, select NAND-first `SYSBOOT[4:0]=10100`, and fully
power cycle. This setting boots NAND first, followed by NAND I2C, SPI0, and
EMAC1. The boot pins are latched at power-on. At the U-Boot prompt,
`md.l 44e10040 1` shows the latched value; its low five bits should be
`0x14` for this setting.

Confirmed on the tested board: NAND SPL loads U-Boot, U-Boot falls through to
NAND recovery without an SD card, and Linux reaches the Buildroot login
prompt. Before relying on recovery, verify repeated NAND-only cold boots for
UBI/ECC errors and test NAND with bad blocks. The installer card has no SD
slot A kernel, so its SD attempt should fall through to NAND recovery.

## TFTP kernel and NFS root

The SD card boots MLO and U-Boot. Its generated `boot.scr` can load the kernel
and DTB from TFTP; Linux then mounts `/srv/zegos/rootfs` over NFS.

### Build

Use a separate output directory for the NFS build:

```sh
docker compose run --rm ubuntu-buildroot make O=output-nfs zegos_chiliboard_nfs_defconfig
docker compose run --rm ubuntu-buildroot sh -c 'make O=output-nfs -j"$(nproc)"'
```

### Workstation setup (Fedora)

Reserve a DHCP address for the board's Ethernet MAC in your router. On the
tested board, `84:eb:18:bc:5e:92` is reserved as `192.168.0.14`. The examples
below use `192.168.0.11` for the workstation. Replace these addresses for
your network. The reservation matters because the NFS export allows only the
board's IP.

```sh
sudo dnf install nfs-utils tftp-server rsync
sudo install -d -m 0755 /srv/zegos/rootfs /var/lib/tftpboot/zegos
```

Create `/etc/exports.d/zegos.exports` with the reserved board address:

```text
/srv/zegos/rootfs 192.168.0.14/32(rw,sync,no_subtree_check,no_root_squash)
```

In the existing `/etc/nfs.conf`, set `port=20048` under `[mountd]`. Then start
the services:

```sh
sudo systemctl enable --now rpcbind nfs-server tftp.socket
sudo systemctl restart nfs-mountd nfs-server
sudo exportfs -ra
```

Find the firewall zone of the workstation interface with
`firewall-cmd --get-active-zones`. On Fedora Workstation it may be
`FedoraWorkstation`, even if another zone is the default. Open all four
services in the **active interface zone**; opening TFTP alone lets the kernel
load but leaves NFS root blocked:

```sh
ZONE=FedoraWorkstation
for service in tftp nfs rpc-bind mountd; do
    sudo firewall-cmd --permanent --zone="$ZONE" --add-service="$service"
done
sudo firewall-cmd --reload
```

The export uses `no_root_squash`; keep it on a trusted development network.

### Deploy and boot

Deploy the kernel, DTB, and root filesystem while the board is off:

```sh
./scripts/deploy-netboot.sh
```

`boot.scr` is included in the SD image, and that build of U-Boot runs it by
default. For NFS boot, set the workstation address once at the U-Boot prompt:

```text
setenv serverip 192.168.0.11
saveenv
run bootcmd
```

If this card already has an older saved U-Boot environment, reset its boot
command to the new compiled default before `saveenv`:

```text
env default -f bootcmd
saveenv
```

`board/chiliboard/boot-fallback.cmd` tries TFTP, SD, then NAND. Set
`disable_tftp`, `disable_sd`, or `disable_nand` to `1` and run `saveenv` to skip
a target. NAND recovery is enabled by default; it will simply fail if no
recovery image has been flashed yet. If an older saved environment has
`disable_nand=1`, use `setenv disable_nand 0; saveenv` to enable it.
`fallback_delay` controls the wait before SD and NAND.
U-Boot can fall back after a download or `bootz` failure; it cannot detect a
failure after Linux starts.

For each kernel or rootfs change, rebuild, run `deploy-netboot.sh`, and
reboot. If `boot-fallback.cmd` changes, rebuild the SD image and reflash the
card, or copy `output-sd-4gb/images/boot.scr` to its FAT boot partition after
the SD image build:

```sh
docker compose run --rm ubuntu-buildroot sh -c 'make O=output-sd-4gb -j"$(nproc)"'
```

`/srv/zegos/rootfs` on the workstation is `/` on the board. Deployment uses
`rsync --delete`, so files copied directly into the export are removed on the
next deploy unless they are in the Buildroot image.

### Stop after development

Power off the board before stopping its NFS root server. Then disable the
servers and close the firewall rules opened above:

```sh
sudo systemctl disable --now tftp.socket nfs-server
ZONE=FedoraWorkstation
for service in tftp nfs rpc-bind mountd; do
    sudo firewall-cmd --permanent --zone="$ZONE" --remove-service="$service"
done
sudo firewall-cmd --reload
```

Use the setup commands above to start the next session.
