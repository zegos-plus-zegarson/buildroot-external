#!/bin/sh
set -eu

board_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
image="${BINARIES_DIR}/sdcard.img"
tmp="${image}.sparse.tmp"
trap 'rm -f "$tmp"' EXIT HUP INT TERM

support/scripts/genimage.sh -c "${board_dir}/genimage.cfg"

# Make the raw disk image sparse on disk; bmaptool then maps its final contents.
cp --sparse=always "$image" "$tmp"
mv -f "$tmp" "$image"
rm -f "${image}.bmap"
bmaptool create "$image" -o "${image}.bmap"
