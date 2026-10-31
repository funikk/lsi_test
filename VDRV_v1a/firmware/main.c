#include <stdint.h>

// MMIO Base Pointer for Load DMA Subsystem (Mapped at 0x80000000)
#define MMIO_BASE        ((volatile uint32_t *)0x80000000)

#define REG_CTRL         (MMIO_BASE[0]) // 0x00
#define REG_STATUS       (MMIO_BASE[1]) // 0x04
#define REG_CFG(i)       (MMIO_BASE[4 + (i)]) // 0x10 - 0x1C
#define REG_SEED(i)      (MMIO_BASE[8 + (i)]) // 0x20 - 0x2C
#define REG_PRNG_DATA(i) (MMIO_BASE[12 + (i)])// 0x30 - 0x3C
#define REG_SRC_ADDR     (MMIO_BASE[16])// 0x40
#define REG_DST_ADDR     (MMIO_BASE[17])// 0x44
#define REG_LEN          (MMIO_BASE[18])// 0x48

// UART & Load Sequencer Base (Mapped at 0x80000100)
#define MMIO_SYS_BASE    ((volatile uint32_t *)0x80000100)
#define REG_UART_TX      (MMIO_SYS_BASE[0]) // 0x00
#define REG_UART_RX      (MMIO_SYS_BASE[1]) // 0x04
#define REG_LOAD_STATE   (MMIO_SYS_BASE[2]) // 0x08 (0x8000_0108)

#define LOAD_STATE_CPU_BIT   0x4
#define LOAD_STATE_CRC_BIT   0x2
#define LOAD_STATE_MAC_BIT   0x1

// DMEM Base Pointer (Mapped at 0x00000000)
#define DMEM_BASE        ((volatile uint32_t *)0x00000000)

void irq_handler(void) {
    // IRQ Handler implementation
}

int main(void) {
    // 1. Program 128-bit Core Configuration (REG_CFG)
    REG_CFG(0) = 0x00112233;
    REG_CFG(1) = 0x44556677;
    REG_CFG(2) = 0x8899aabb;
    REG_CFG(3) = 0xccddeeff;

    // 2. Program 128-bit PRNG Seed & pulse SEED_LOAD
    REG_SEED(0) = 0x12345678;
    REG_SEED(1) = 0x9abcdef0;
    REG_SEED(2) = 0x01234567;
    REG_SEED(3) = 0x89abcdef;
    REG_CTRL    = 0x04; // Pulse SEED_LOAD bit

    // 3. Read PRNG Data and store to DMEM at offset 0x100 (word index 64..67)
    DMEM_BASE[64] = REG_PRNG_DATA(0);
    DMEM_BASE[65] = REG_PRNG_DATA(1);
    DMEM_BASE[66] = REG_PRNG_DATA(2);
    DMEM_BASE[67] = REG_PRNG_DATA(3);

    // 4. Store source block in DMEM at offset 0x00 (word index 0..3)
    DMEM_BASE[0] = 0x01234567;
    DMEM_BASE[1] = 0x89abcdef;
    DMEM_BASE[2] = 0x00000111;
    DMEM_BASE[3] = 0x00000222;

    // 5. Run DMA in MAC mode (DMA_MODE_SEL = 00, REG_DST_ADDR = 0x00000020, REG_LEN = 1, REG_CTRL = 0x01)
    REG_SRC_ADDR = 0x00000000;
    REG_DST_ADDR = 0x00000020;
    REG_LEN      = 1;
    REG_CTRL     = 0x01;
    while ((REG_STATUS & 0x02) == 0) { }

    // 6. Run DMA in CRC mode (DMA_MODE_SEL = 01, REG_DST_ADDR = 0x00000030, REG_LEN = 1, REG_CTRL = 0x11)
    REG_SRC_ADDR = 0x00000000;
    REG_DST_ADDR = 0x00000030;
    REG_LEN      = 1;
    REG_CTRL     = 0x11;
    while ((REG_STATUS & 0x02) == 0) { }

    // 7. Run finite-block continuous load mode with BOTH MAC and CRC enabled (REG_LEN = 3, REG_CTRL = 0x0A (MAC_LOAD_EN | CRC_LOAD_EN))
    REG_LEN  = 3;
    REG_CTRL = 0x0A;
    while ((REG_STATUS & 0x02) == 0) { }

    // 8. Run infinite load mode (REG_LEN = 0, REG_CTRL = 0x0A) for 30 NOPs, then stop (REG_CTRL = 0x00)
    REG_LEN  = 0;
    REG_CTRL = 0x0A;
    for (volatile int i = 0; i < 30; i++) {
        __asm__ volatile("nop");
    }
    REG_CTRL = 0x00;

    // 9. Write completion marker DMEM_BASE[63] = 0xDEADBEEF
    DMEM_BASE[63] = 0xDEADBEEF;

    // 10. Enter infinite loop polling REG_LOAD_STATE (0x8000_0108):
    // if bit 2 (LOAD_STATE_CPU_BIT) is set, run intensive ALU/memory loop; otherwise run light NOP loop.
    while (1) {
        uint32_t state = REG_LOAD_STATE;
        if (state & LOAD_STATE_CPU_BIT) {
            for (volatile int i = 0; i < 50; i++) {
                DMEM_BASE[100 + (i % 16)] = i * 7;
            }
        } else {
            for (volatile int i = 0; i < 5; i++) {
                __asm__ volatile("nop");
            }
        }
    }

    return 0;
}
