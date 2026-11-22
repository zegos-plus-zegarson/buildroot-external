# U-Boot script for chiliBoard. Load this boot.scr from the SD boot partition.
# MLO and U-Boot remain on SD; kernel and DTB are fetched from TFTP.

if test -z "${disable_tftp}"; then setenv disable_tftp 0; fi
if test -z "${disable_sd}"; then setenv disable_sd 0; fi
if test -z "${disable_nand}"; then setenv disable_nand 1; fi
if test -z "${fallback_delay}"; then setenv fallback_delay 2; fi
if test -z "${nfsroot}"; then setenv nfsroot /srv/zegos/rootfs; fi
# The board's old U-Boot default is ttyO0; Linux 6.12 names this UART ttyS0.
setenv console ttyS0

# Bound network retries so an unavailable server eventually gives way to SD.
setenv netretry no
setenv tftptimeout 2000
setenv tftptimeoutcountmax 3

if test "${disable_tftp}" = "1"; then
    echo "[BOOT] TFTP disabled"
else
    echo "[BOOT] Trying TFTP"
    setenv autoload no
    if dhcp; then
        setenv autoload
        if tftpboot ${loadaddr} zegos/zImage; then
            if tftpboot ${fdt_addr} zegos/${fdt_file}; then
                if run netargs; then
                    setenv bootargs ${bootargs} rw
                    echo "[BOOT] Booting TFTP kernel with NFS root"
                    bootz ${loadaddr} - ${fdt_addr}
                fi
            else
                echo "[BOOT] TFTP device tree download failed"
            fi
        else
            echo "[BOOT] TFTP kernel download failed"
        fi
    else
        echo "[BOOT] DHCP failed"
    fi
    setenv autoload
    echo "[BOOT] TFTP failed"
fi

if test "${disable_sd}" = "1"; then
    echo "[BOOT] SD disabled"
else
    echo "[BOOT] Waiting ${fallback_delay}s before SD"
    sleep ${fallback_delay}
    echo "[BOOT] Trying SD (mmc 0)"
    if mmc dev 0 && mmc rescan; then
        if fatload mmc 0:1 ${loadaddr} zImage; then
            if fatload mmc 0:1 ${fdt_addr} ${fdt_file}; then
                if run mmcargs; then
                    echo "[BOOT] Booting SD kernel with SD root"
                    bootz ${loadaddr} - ${fdt_addr}
                fi
            fi
        fi
    fi
    echo "[BOOT] SD failed"
fi

if test "${disable_nand}" = "1"; then
    echo "[BOOT] NAND disabled"
else
    echo "[BOOT] Waiting ${fallback_delay}s before NAND"
    sleep ${fallback_delay}
    echo "[BOOT] Trying NAND"
    if run nandargs; then
        if nand read ${fdt_addr} NAND.u-boot-spl-os; then
            if nand read ${loadaddr} NAND.kernel; then
                echo "[BOOT] Booting NAND kernel with UBI root"
                bootz ${loadaddr} - ${fdt_addr}
            fi
        fi
    fi
    echo "[BOOT] NAND failed"
fi

echo "[BOOT] All enabled boot sources failed; entering U-Boot prompt"
false
