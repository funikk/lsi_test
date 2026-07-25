.section .text.start
.global _start
_start:
    j reset_handler
    .balign 16
    /* IRQ Vector at 0x10 */
irq_entry:
    addi sp, sp, -64
    sw x1,  0(sp)
    sw x3,  4(sp)
    sw x4,  8(sp)
    sw x5,  12(sp)
    sw x6,  16(sp)
    sw x7,  20(sp)
    sw x10, 24(sp)
    sw x11, 28(sp)
    sw x12, 32(sp)
    sw x13, 36(sp)
    sw x14, 40(sp)
    sw x15, 44(sp)
    sw x16, 48(sp)
    sw x17, 52(sp)

    call irq_handler

    lw x17, 52(sp)
    lw x16, 48(sp)
    lw x15, 44(sp)
    lw x14, 40(sp)
    lw x13, 36(sp)
    lw x12, 32(sp)
    lw x11, 28(sp)
    lw x10, 24(sp)
    lw x7,  20(sp)
    lw x6,  16(sp)
    lw x5,  12(sp)
    lw x4,  8(sp)
    lw x3,  4(sp)
    lw x1,  0(sp)
    addi sp, sp, 64

    /* Return using x3 */
    jalr x0, x3, 0

reset_handler:
    /* Set stack pointer to top of DMEM / Stack area */
    li sp, 0x00000800
    /* Call C main function */
    call main

    /* Infinite loop if main returns */
trap_loop:
    j trap_loop
