#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
images_dir="${IMAGES_DIR:-${script_dir}/../../buildroot/output-nfs/images}"
staging=$(mktemp -d)
trap 'sudo rm -rf -- "$staging"' EXIT

sudo tar --numeric-owner -xpf "$images_dir/rootfs.tar" -C "$staging"
sudo rsync -a --numeric-ids --delete "$staging/" /srv/zegos/rootfs/
sudo install -m 0644 "$images_dir/zImage" /var/lib/tftpboot/zegos/zImage
sudo install -m 0644 "$images_dir/am335x-chiliboard.dtb" /var/lib/tftpboot/zegos/am335x-chiliboard.dtb
