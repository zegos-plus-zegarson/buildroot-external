#!/bin/sh
set -eu

board_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
install -d "${TARGET_DIR}/boot" "${TARGET_DIR}/etc/init.d" "${TARGET_DIR}/data"
install -m 0644 "${BINARIES_DIR}/zImage" "${TARGET_DIR}/boot/zImage"
install -m 0644 "${BINARIES_DIR}/vexpress-v2p-ca9.dtb" "${TARGET_DIR}/boot/vexpress-v2p-ca9.dtb"
install -m 0755 "${board_dir}/target/etc/init.d/S05mount-data" "${TARGET_DIR}/etc/init.d/S05mount-data"
