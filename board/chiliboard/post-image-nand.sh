#!/bin/sh
set -eu

images="${BINARIES_DIR}"
board_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# These are NAND-aware flash inputs, not a raw whole-chip image. U-Boot must
# write them through its NAND driver so bad blocks and OOB/ECC are handled.
for name in MLO u-boot.img am335x-chiliboard.dtb zImage rootfs.ubi; do
	test -s "${images}/${name}" || {
		echo "Missing NAND recovery artifact: ${name}" >&2
		exit 1
	}
done

check_fits() {
	actual=$(stat -c %s "${images}/$1")
	if [ "$actual" -gt "$2" ]; then
		echo "$1 is $actual bytes; limit is $2 bytes" >&2
		exit 1
	fi
}

check_fits MLO 131072
check_fits u-boot.img 1048576
check_fits am335x-chiliboard.dtb 262144
check_fits zImage 8388608
# The UBI partition is 246 MiB. Leave 6 MiB for bad blocks and UBI overhead.
check_fits rootfs.ubi 251658240

"${HOST_DIR}/bin/mkimage" -A arm -T script -C none \
	-d "${board_dir}/flash-nand.cmd" "${images}/flash-nand.scr"
support/scripts/genimage.sh -c "${board_dir}/genimage-nand-installer.cfg"
