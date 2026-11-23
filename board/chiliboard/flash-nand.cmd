# Run manually from the NAND installer SD card at the U-Boot prompt:
# load mmc 0:1 0x81000000 flash-nand.scr; source 0x81000000
# This erases the recovery partitions and both NAND environment copies.

# Check every input before changing NAND. U-Boot's hush parser does not
# handle backslash-newline as a shell line continuation.
if mtdparts default; then echo '[FLASH] NAND partitions ready'; else echo '[FLASH] NAND partition setup failed'; exit 1; fi
if load mmc 0:1 ${loadaddr} MLO; then echo '[FLASH] MLO found'; else echo '[FLASH] MLO missing'; exit 1; fi
if load mmc 0:1 ${loadaddr} u-boot.img; then echo '[FLASH] U-Boot found'; else echo '[FLASH] U-Boot missing'; exit 1; fi
if load mmc 0:2 ${loadaddr} nand/am335x-chiliboard.dtb; then echo '[FLASH] device tree found'; else echo '[FLASH] device tree missing'; exit 1; fi
if load mmc 0:2 ${loadaddr} nand/zImage; then echo '[FLASH] kernel found'; else echo '[FLASH] kernel missing'; exit 1; fi
if load mmc 0:2 ${loadaddr} nand/rootfs.ubi; then echo '[FLASH] UBI image found'; else echo '[FLASH] UBI image missing'; exit 1; fi

if load mmc 0:1 ${loadaddr} MLO; then setenv flash_size ${filesize}; else echo '[FLASH] MLO load failed'; exit 1; fi
if nand erase.part NAND.SPL && nand write ${loadaddr} NAND.SPL ${flash_size}; then echo '[FLASH] SPL copy 0 written'; else echo '[FLASH] SPL copy 0 failed'; exit 1; fi
if nand erase.part NAND.SPL.backup1 && nand write ${loadaddr} NAND.SPL.backup1 ${flash_size}; then echo '[FLASH] SPL copy 1 written'; else echo '[FLASH] SPL copy 1 failed'; exit 1; fi
if nand erase.part NAND.SPL.backup2 && nand write ${loadaddr} NAND.SPL.backup2 ${flash_size}; then echo '[FLASH] SPL copy 2 written'; else echo '[FLASH] SPL copy 2 failed'; exit 1; fi
if nand erase.part NAND.SPL.backup3 && nand write ${loadaddr} NAND.SPL.backup3 ${flash_size}; then echo '[FLASH] SPL copy 3 written'; else echo '[FLASH] SPL copy 3 failed'; exit 1; fi

if load mmc 0:2 ${loadaddr} nand/am335x-chiliboard.dtb; then setenv flash_size ${filesize}; else echo '[FLASH] device tree load failed'; exit 1; fi
if nand erase.part NAND.u-boot-spl-os && nand write ${loadaddr} NAND.u-boot-spl-os ${flash_size}; then echo '[FLASH] device tree written'; else echo '[FLASH] device tree write failed'; exit 1; fi

if load mmc 0:1 ${loadaddr} u-boot.img; then setenv flash_size ${filesize}; else echo '[FLASH] U-Boot load failed'; exit 1; fi
if nand erase.part NAND.u-boot && nand write ${loadaddr} NAND.u-boot ${flash_size}; then echo '[FLASH] U-Boot written'; else echo '[FLASH] U-Boot write failed'; exit 1; fi

if load mmc 0:2 ${loadaddr} nand/zImage; then setenv flash_size ${filesize}; else echo '[FLASH] kernel load failed'; exit 1; fi
if nand erase.part NAND.kernel && nand write ${loadaddr} NAND.kernel ${flash_size}; then echo '[FLASH] kernel written'; else echo '[FLASH] kernel write failed'; exit 1; fi

if load mmc 0:2 ${loadaddr} nand/rootfs.ubi; then setenv flash_size ${filesize}; else echo '[FLASH] UBI image load failed'; exit 1; fi
if nand erase.part NAND.file-system && nand write.trimffs ${loadaddr} NAND.file-system ${flash_size}; then echo '[FLASH] UBI image written'; else echo '[FLASH] UBI image write failed'; exit 1; fi

if nand erase.part NAND.u-boot-env && nand erase.part NAND.u-boot-env.backup1; then
    echo '[FLASH] NAND recovery written; select NAND boot and reset'
else
    echo '[FLASH] NAND environment erase failed; keep SD inserted'
    exit 1
fi
