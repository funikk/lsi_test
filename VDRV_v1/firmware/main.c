#include <stdint.h>

// MMIO Base Pointer (Mapped at 0x80000000)
#define MMIO_BASE        ((volatile uint32_t *)0x80000000)

#define REG_CTRL         (MMIO_BASE[0]) // 0x00
#define REG_STATUS       (MMIO_BASE[1]) // 0x04
#define REG_KEY(i)       (MMIO_BASE[4 + (i)]) // 0x10 - 0x1C
#define REG_SEED(i)      (MMIO_BASE[8 + (i)]) // 0x20 - 0x2C
#define REG_PRNG_DATA(i) (MMIO_BASE[12 + (i)])// 0x30 - 0x3C
#define REG_SRC_ADDR     (MMIO_BASE[16])// 0x40
#define REG_DST_ADDR     (MMIO_BASE[17])// 0x44
#define REG_LEN          (MMIO_BASE[18])// 0x48

// UART & Load Sequencer Base (Mapped at 0x80000100)
#define MMIO_SYS_BASE    ((volatile uint32_t *)0x80000100)
#define REG_UART_TX      (MMIO_SYS_BASE[0]) // 0x00
#define REG_UART_RX      (MMIO_SYS_BASE[1]) // 0x04
#define REG_LOAD_STATE   (MMIO_SYS_BASE[2]) // 0x08

#define LOAD_STATE_IDLE      0
#define LOAD_STATE_CPU_FULL  1
#define LOAD_STATE_AES_FULL  2
#define LOAD_STATE_BOTH_FULL 3

// DMEM Base Pointer (Mapped at 0x00000000)
#define DMEM_BASE        ((volatile uint32_t *)0x00000000)

void irq_handler(void) {
    // IRQ Handler implementation
}

int main(void) {
    // 1. Set 128-bit AES Key
    REG_KEY(0) = 0x00112233;
    REG_KEY(1) = 0x44556677;
    REG_KEY(2) = 0x8899aabb;
    REG_KEY(3) = 0xccddeeff;

    // 2. Set 128-bit PRNG Seed
    REG_SEED(0) = 0x12345678;
    REG_SEED(1) = 0x9abcdef0;
    REG_SEED(2) = 0x01234567;
    REG_SEED(3) = 0x89abcdef;
    REG_CTRL    = 0x04; // Pulse SEED_LOAD bit

    // 3. Read PRNG Data and store to DMEM at offset 0x100 (word index 64)
    DMEM_BASE[64] = REG_PRNG_DATA(0);
    DMEM_BASE[65] = REG_PRNG_DATA(1);
    DMEM_BASE[66] = REG_PRNG_DATA(2);
    DMEM_BASE[67] = REG_PRNG_DATA(3);

    // 4. Store Plaintext data in DMEM at offset 0x00 (word indices 0..3)
    DMEM_BASE[0] = 0x01234567;
    DMEM_BASE[1] = 0x89abcdef;
    DMEM_BASE[2] = 0x00000111;
    DMEM_BASE[3] = 0x00000222;

    // 5. Configure & Start DMA Encryption (1 block)
    REG_SRC_ADDR = 0x00000000;
    REG_DST_ADDR = 0x00000020;
    REG_LEN      = 1;      // 1 block (16 bytes)
    REG_CTRL     = 0x01;   // Start DMA

    // 6. Poll STATUS register until bit 1 (DMA_DONE) is set
    while ((REG_STATUS & 0x02) == 0) { }

    // 7. Test Finite-Block Auto-Return Load Mode (DMA_LEN = 5)
    REG_LEN  = 5;      // Run 5 encryptions in high-load mode
    REG_CTRL = 0x02;   // Start LOAD_MODE_EN
    while ((REG_STATUS & 0x02) == 0) {
        // Wait for automatic completion of 5 blocks and hardware auto-return
    }

    // 8. Test Infinite Load Mode with Manual CPU Return (DMA_LEN = 0)
    REG_LEN  = 0;      // Infinite load mode
    REG_CTRL = 0x02;   // Start LOAD_MODE_EN
    for (volatile int i = 0; i < 50; i++) {
        __asm__ volatile("nop");
    }
    REG_CTRL = 0x00;   // Explicitly write LOAD_MODE_EN = 0 to return to normal mode

    // 9. Store Magic Completion Marker 0xDEADBEEF in DMEM at offset 0xFC (word index 63)
    DMEM_BASE[63] = 0xDEADBEEF;

    // Infinite loop
    while (1) {
        uint32_t state = REG_LOAD_STATE;
        if (state == LOAD_STATE_CPU_FULL || state == LOAD_STATE_BOTH_FULL) {
            // Intensive ALU/memory activity loop
            for (volatile int i = 0; i < 50; i++) {
                DMEM_BASE[100 + (i % 16)] = i * 7;
            }
        } else {
            // Light polling loop / WFI
            for (volatile int i = 0; i < 5; i++) {
                __asm__ volatile("nop");
            }
        }
    }

    return 0;
}
