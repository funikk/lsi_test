OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
    imem (rx) : ORIGIN = 0x00000000, LENGTH = 8K
}

SECTIONS {
    .text : {
        *(.text.start)
        *(.text*)
        *(.rodata*)
    } > imem

    /DISCARD/ : {
        *(.eh_frame)
        *(.comment)
    }
}
