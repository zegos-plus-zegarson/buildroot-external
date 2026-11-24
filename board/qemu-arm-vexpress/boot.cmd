# QEMU vexpress-a9 SD boot: slot A, then a separate recovery partition.
# Slot B is populated for the future switch mechanism, as on chiliBoard.
echo "[BOOT] Trying SD rootfs A"
if fatload mmc 0:1 0x64000000 zImage; then
    if fatload mmc 0:1 0x62000000 vexpress-v2p-ca9.dtb; then
        setenv bootargs console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootwait rw
        bootz 0x64000000 - 0x62000000
    fi
fi

echo "[BOOT] Trying recovery"
if ext4load mmc 0:4 0x64000000 /boot/zImage; then
    if ext4load mmc 0:4 0x62000000 /boot/vexpress-v2p-ca9.dtb; then
        setenv bootargs console=ttyAMA0,115200 root=/dev/mmcblk0p4 rootwait rw
        bootz 0x64000000 - 0x62000000
    fi
fi
echo "[BOOT] Recovery unavailable; entering U-Boot prompt"
false
