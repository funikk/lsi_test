.section .text.start
.global _start
_start:
    /* Set stack pointer to top of DMEM / Stack area */
    li sp, 0x00000800
    /* Call C main function */
    call main

    /* Infinite loop if main returns */
trap_loop:
    j trap_loop
