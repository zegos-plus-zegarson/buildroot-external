#!/bin/sh
set -eu

board_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
image="${BINARIES_DIR}/sdcard.img"
tmp="${image}.sparse.tmp"
trap 'rm -f "$tmp"' EXIT HUP INT TERM

"${HOST_DIR}/bin/mkimage" -A arm -T script -C none \
	-d "${board_dir}/boot-fallback.cmd" "${BINARIES_DIR}/boot.scr"

userdata="${BINARIES_DIR}/userdata.ext4"
userdata_size=$((925 * 1024 * 1024))

# Preserve a staged userdata image on incremental builds, but reject one
# created for a different card layout.
if [ -f "$userdata" ]; then
	if [ "$(stat -c %s "$userdata")" -ne "$userdata_size" ]; then
		echo "userdata.ext4 must be $userdata_size bytes" >&2
		exit 1
	fi
else
	truncate -s "$userdata_size" "$userdata"
	MKE2FS_CONFIG="${HOST_DIR}/etc/mke2fs.conf" \
		"${HOST_DIR}/sbin/mkfs.ext4" -F -m 0 -L userdata "$userdata"
fi

# Give B a distinct filesystem identity even before slot switching exists.
cp --sparse=always "${BINARIES_DIR}/rootfs.ext4" "${BINARIES_DIR}/rootfs_b.ext4"
"${HOST_DIR}/sbin/tune2fs" -U random -L rootfs_b "${BINARIES_DIR}/rootfs_b.ext4"

support/scripts/genimage.sh -c "${board_dir}/genimage-sd-4gb.cfg"

# Make the raw disk image sparse. genimage.sh already created a bmap; the
# image's bytes are unchanged, so that map remains valid after this copy.
cp --sparse=always "$image" "$tmp"
mv -f "$tmp" "$image"

# Leave room for the MBR and partitions on a nominal 4 GB card.
test "$(stat -c %s "$image")" -le 4000000000 || {
	echo 'sdcard.img exceeds a nominal 4 GB card' >&2
	exit 1
}
