#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
images=${1:-"${root}/../buildroot/output-qemu-arm-vexpress/images"}
state=${QEMU_STATE_DIR:-"${root}/.qemu-arm-vexpress"}
qemu="${images}/../host/bin/qemu-system-arm"
if [ ! -x "$qemu" ]; then
    qemu=qemu-system-arm
fi
if [ ! -f "${images}/u-boot" ] || [ ! -f "${images}/disk.img" ]; then
    echo "Missing QEMU build artifacts in ${images}" >&2
    exit 1
fi
mkdir -p "$state"
if [ "${QEMU_RESET_DISK:-0}" = 1 ] || [ ! -f "${state}/disk.img" ]; then
    cp --sparse=always "${images}/disk.img" "${state}/disk.img"
fi
exec "$qemu" -machine vexpress-a9 -m 512M -smp 1 -nographic \
    -kernel "${images}/u-boot" \
    -drive "if=sd,file=${state}/disk.img,format=raw" \
    -net nic,model=lan9118 -net user
