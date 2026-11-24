#!/bin/sh
set -eu

board_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"${HOST_DIR}/bin/mkimage" -A arm -T script -C none \
    -d "${board_dir}/boot.cmd" "${BINARIES_DIR}/boot.scr"

cp --sparse=always "${BINARIES_DIR}/rootfs.ext4" "${BINARIES_DIR}/rootfs_b.ext4"
"${HOST_DIR}/sbin/tune2fs" -U random -L rootfs_b "${BINARIES_DIR}/rootfs_b.ext4"
cp --sparse=always "${BINARIES_DIR}/rootfs.ext4" "${BINARIES_DIR}/recovery.ext4"
"${HOST_DIR}/sbin/tune2fs" -U random -L recovery "${BINARIES_DIR}/recovery.ext4"
"${HOST_DIR}/sbin/tune2fs" -L rootfs_a "${BINARIES_DIR}/rootfs.ext4"

truncate -s 128M "${BINARIES_DIR}/data.ext4"
MKE2FS_CONFIG="${HOST_DIR}/etc/mke2fs.conf" \
    "${HOST_DIR}/sbin/mkfs.ext4" -F -m 0 -L data "${BINARIES_DIR}/data.ext4"

support/scripts/genimage.sh -c "${board_dir}/genimage.cfg"

# genimage writes every sector; keep the working disk sparse on the host.
cp --sparse=always "${BINARIES_DIR}/disk.img" "${BINARIES_DIR}/disk.img.sparse"
mv -f "${BINARIES_DIR}/disk.img.sparse" "${BINARIES_DIR}/disk.img"
