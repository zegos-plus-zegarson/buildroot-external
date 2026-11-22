# ZegOS: chiliBoard Premium

Tested board: AM3352, 256 MiB RAM, 256 MiB NAND.

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

Serial console: 115200 8N1 through the micro USB debug port.

## TFTP kernel and NFS root

The SD card still boots MLO and U-Boot. U-Boot loads the kernel and DTB from
TFTP, then Linux mounts `/srv/zegos/rootfs` from the workstation over NFS.

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

Copy `../buildroot/output-nfs/images/boot.scr` to the SD card's FAT boot
partition. At the U-Boot prompt, set the workstation address and boot command
once:

```text
setenv serverip 192.168.0.11
setenv scriptaddr 0x81000000
setenv bootcmd 'if load mmc 0:1 ${scriptaddr} boot.scr; then source ${scriptaddr}; else run mmcboot; run nandboot; fi'
saveenv
run bootcmd
```

`board/chiliboard/boot-fallback.cmd` tries TFTP, SD, then NAND. Set
`disable_tftp`, `disable_sd`, or `disable_nand` to `1` and run `saveenv` to skip
a target. NAND starts disabled because this project does not build a NAND
image. `fallback_delay` controls the wait before SD and NAND. U-Boot can fall
back after a download or `bootz` failure; it cannot detect a failure after
Linux starts.

For each kernel or rootfs change, rebuild, run `deploy-netboot.sh`, and
reboot. If `boot-fallback.cmd` changes, regenerate `boot.scr` and copy it to
the SD boot partition:

```sh
docker compose run --rm ubuntu-buildroot make O=output-nfs host-uboot-tools-rebuild
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
