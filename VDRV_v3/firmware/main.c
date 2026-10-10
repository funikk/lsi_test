#include <stdint.h>

// ====================================================================
// VDRV_v3 Memory Map Definitions
// ====================================================================

// DMEM
#define DMEM_BASE             ((volatile uint32_t *)0x00000000)

// System Controller (0x8000_0000)
#define SYS_CTRL_BASE         ((volatile uint32_t *)0x80000000)
#define REG_SYS_SCENARIO      (SYS_CTRL_BASE[0])  // 0x00 [3:0] scenario_sel (R)
#define REG_SYS_STATUS        (SYS_CTRL_BASE[1])  // 0x04 [0] done, [1] sig_ok (RW)
#define REG_SYS_MARKER        (SYS_CTRL_BASE[2])  // 0x08 [1:0] marker (RW)
#define REG_SYS_SIG_OUT       (SYS_CTRL_BASE[3])  // 0x0C [7:0] sig_out (RW)
#define REG_SYS_CYCLE         (SYS_CTRL_BASE[4])  // 0x10 free-running counter (R)

// Load Sequencer (0x8000_0100)
#define SEQ_BASE              ((volatile uint32_t *)0x80000100)
#define REG_SEQ_CTRL          (SEQ_BASE[0])       // 0x00
#define REG_SEQ_STATUS        (SEQ_BASE[1])       // 0x04
#define REG_STEP_W0(s)        (SEQ_BASE[16 + 2*(s)])     // 0x40 + 8*s
#define REG_STEP_W1(s)        (SEQ_BASE[16 + 2*(s) + 1]) // 0x44 + 8*s

// Power Manager (0x8000_0200)
#define PWR_BASE              ((volatile uint32_t *)0x80000200)
#define REG_PWR_REQ           (PWR_BASE[0])       // 0x00 [G-1:0]
#define REG_PWR_STATUS        (PWR_BASE[1])       // 0x04 [7:0] ON, [15:8] trans, [23:16] eff
#define REG_PWR_T_TRICKLE     (PWR_BASE[2])       // 0x08
#define REG_PWR_T_MAIN        (PWR_BASE[3])       // 0x0C
#define REG_PWR_STAGGER       (PWR_BASE[4])       // 0x10
#define REG_PWR_ORDER         (PWR_BASE[5])       // 0x14
#define REG_PWR_UNSAFE        (PWR_BASE[6])       // 0x18

// Tile Config Bridge (0x8000_0300)
#define CFG_BASE              ((volatile uint32_t *)0x80000300)
#define REG_CFG_TARGET        (CFG_BASE[0])       // 0x00 [7:0] id, [12:8] addr
#define REG_CFG_WDATA         (CFG_BASE[1])       // 0x04 write triggers cfg_valid
#define REG_CFG_CTRL          (CFG_BASE[2])       // 0x08 [0] sync pulse, [5:4] profile_id
#define REG_CFG_SIG_SEL       (CFG_BASE[3])       // 0x0C
#define REG_CFG_SIG_DATA      (CFG_BASE[4])       // 0x10
#define REG_CFG_SIG_XOR       (CFG_BASE[5])       // 0x14
#define REG_CFG_NUM_TILES     (CFG_BASE[6])       // 0x18

// EM Stress Block (0x8000_0400)
#define EM_BASE               ((volatile uint32_t *)0x80000400)
#define REG_EM_CTRL           (EM_BASE[0])        // 0x00 [0] bus, [1] fo, [2] pat
#define REG_EM_SIG            (EM_BASE[1])        // 0x04

// ====================================================================
// Helper Functions
// ====================================================================

static inline void tile_write(uint8_t tile_id, uint8_t addr, uint32_t data) {
    REG_CFG_TARGET = ((uint32_t)addr << 8) | tile_id;
    REG_CFG_WDATA  = data;
}

static inline void sync_pulse(void) {
    REG_CFG_CTRL = 0x01; // bit 0 self-clears
}

static inline void wait_cycles(uint32_t count) {
    for (volatile uint32_t i = 0; i < count; i++) {
        __asm__ volatile("nop");
    }
}

// Build 32-bit PG_CTRL register value
static inline uint32_t make_pg_ctrl(uint8_t mode, uint8_t act_level, uint8_t gate_mode) {
    return ((uint32_t)(gate_mode & 0x01) << 12) |
           ((uint32_t)(act_level & 0x1F) << 4)  |
           ((uint32_t)(mode & 0x03));
}

// Build 32-bit STEP_W0 register value
static inline uint32_t make_step_w0(uint16_t dur, uint8_t prof, uint8_t marker, uint8_t em) {
    return ((uint32_t)(em & 0x07) << 24)     |
           ((uint32_t)(marker & 0x03) << 20) |
           ((uint32_t)(prof & 0x03) << 16)   |
           (uint32_t)dur;
}

// ====================================================================
// Interrupt Handler
// ====================================================================

void irq_handler(void) {
    // Acknowledged via eoi in start.S
}

// ====================================================================
// Main Execution
// ====================================================================

int main(void) {
    uint32_t scenario = REG_SYS_SCENARIO & 0x0F;
    uint32_t num_tiles = REG_CFG_NUM_TILES;

    // Default power-up all PD groups safely
    REG_PWR_STAGGER   = 4;
    REG_PWR_T_TRICKLE = 8;
    REG_PWR_T_MAIN    = 8;
    REG_PWR_REQ       = 0xFF; // Request all groups

    // Wait until all groups are powered ON (at least group 0 and 1)
    while ((REG_PWR_STATUS & 0x03) != 0x03) {
        // Polling power manager
    }

    // Default: Reset all tile signatures and set default seed
    tile_write(0xFF, 0x10, 0x03); // sig_clear=1, seed_load=1
    tile_write(0xFF, 0x11, 0x12345678);

    // Profile 0: Always ON, 100% activity, no clock gating
    tile_write(0xFF, 0x00, make_pg_ctrl(1, 16, 0));

    // Profile 1: OFF, 0% activity, clock gating enabled
    tile_write(0xFF, 0x04, make_pg_ctrl(0, 0, 1));

    // Profile 2: Periodic, period 10, duty 5
    tile_write(0xFF, 0x08, make_pg_ctrl(2, 16, 0));
    tile_write(0xFF, 0x09, (5 << 16) | 10); // duty=5, period=10
    tile_write(0xFF, 0x0A, 0);              // phase=0

    // Profile 3: Random burst, 100% activity
    tile_write(0xFF, 0x0C, make_pg_ctrl(3, 16, 0));

    // Execute Selected Scenario
    switch (scenario) {
        case 0: // IDLE: Keep all tiles gated OFF
            REG_STEP_W0(0) = make_step_w0(10, 1, 0, 0); // profile 1 (OFF)
            REG_STEP_W1(0) = 0xFF;
            REG_SEQ_CTRL   = (4 << 16) | (0 << 4) | 0x06; // ONESHOT, ENABLE, total=0
            break;

        case 1: // ALL_ON_SYNC: Profile 0 for 20 ticks
        default:
            REG_STEP_W0(0) = make_step_w0(20, 0, 1, 0); // profile 0, marker=1
            REG_STEP_W1(0) = 0xFF;
            REG_SEQ_CTRL   = (4 << 16) | (0 << 4) | 0x06; // ONESHOT, ENABLE, total=0
            break;

        case 2: // STEP_LOAD: Step 0 (OFF, 10 ticks) -> Step 1 (ALL_ON, 20 ticks)
            REG_STEP_W0(0) = make_step_w0(10, 1, 0, 0); // OFF
            REG_STEP_W1(0) = 0xFF;
            REG_STEP_W0(1) = make_step_w0(20, 0, 2, 0); // ALL_ON, marker=2
            REG_STEP_W1(1) = 0xFF;
            REG_SEQ_CTRL   = (4 << 16) | (1 << 4) | 0x06; // ONESHOT, ENABLE, total=1
            break;

        case 3: // STAGGERED: Set phased periodic profile and start
            tile_write(0x00, 0x0A, 0); // Phase 0
            tile_write(0x01, 0x0A, 2); // Phase 2
            tile_write(0x02, 0x0A, 4); // Phase 4
            tile_write(0x10, 0x0A, 6); // Phase 6
            tile_write(0x11, 0x0A, 8); // Phase 8
            REG_STEP_W0(0) = make_step_w0(30, 2, 1, 0); // profile 2, marker=1
            REG_STEP_W1(0) = 0xFF;
            REG_SEQ_CTRL   = (4 << 16) | (0 << 4) | 0x06;
            break;

        case 4: // RESONANCE: Periodic profile 2 for 40 ticks
            REG_STEP_W0(0) = make_step_w0(40, 2, 1, 0);
            REG_STEP_W1(0) = 0xFF;
            REG_SEQ_CTRL   = (4 << 16) | (0 << 4) | 0x06;
            break;

        case 5: // HOTSPOT: Tile 00 ON, others OFF
            tile_write(0xFF, 0x00, make_pg_ctrl(0, 0, 1));  // All OFF
            tile_write(0x00, 0x00, make_pg_ctrl(1, 16, 0)); // Tile 00 ON
            REG_STEP_W0(0) = make_step_w0(20, 0, 1, 0);
            REG_STEP_W1(0) = 0xFF;
            REG_SEQ_CTRL   = (4 << 16) | (0 << 4) | 0x06;
            break;

        case 6: // CHECKER: Checkerboard pattern
            tile_write(0xFF, 0x00, make_pg_ctrl(0, 0, 1));
            tile_write(0x00, 0x00, make_pg_ctrl(1, 16, 0));
            tile_write(0x02, 0x00, make_pg_ctrl(1, 16, 0));
            tile_write(0x11, 0x00, make_pg_ctrl(1, 16, 0));
            REG_STEP_W0(0) = make_step_w0(20, 0, 1, 0);
            REG_STEP_W1(0) = 0xFF;
            REG_SEQ_CTRL   = (4 << 16) | (0 << 4) | 0x06;
            break;

        case 8: // PWRUP_SAFE: Power down first, then power up with stagger
            REG_PWR_REQ = 0x00;
            while ((REG_PWR_STATUS & 0xFF) != 0x00) { }
            REG_PWR_STAGGER = 8;
            REG_PWR_REQ = 0xFF;
            while ((REG_PWR_STATUS & 0x03) != 0x03) { }
            REG_STEP_W0(0) = make_step_w0(10, 0, 1, 0);
            REG_STEP_W1(0) = 0xFF;
            REG_SEQ_CTRL   = (4 << 16) | (0 << 4) | 0x06;
            break;

        case 9: // PWRUP_UNSAFE: Unsafe mode fast power-up
            REG_PWR_REQ = 0x00;
            while ((REG_PWR_STATUS & 0xFF) != 0x00) { }
            REG_PWR_UNSAFE = 1;
            REG_PWR_REQ = 0xFF;
            while ((REG_PWR_STATUS & 0x03) != 0x03) { }
            REG_STEP_W0(0) = make_step_w0(10, 0, 1, 0);
            REG_STEP_W1(0) = 0xFF;
            REG_SEQ_CTRL   = (4 << 16) | (0 << 4) | 0x06;
            break;

        case 11: // EM_STRESS: Enable EM bus and fanout nets + All Tiles ON
            REG_STEP_W0(0) = make_step_w0(25, 0, 3, 3); // EM_CTRL=3 (bus + fo)
            REG_STEP_W1(0) = 0xFF;
            REG_SEQ_CTRL   = (4 << 16) | (0 << 4) | 0x06;
            break;
    }

    // Wait until Sequencer completes (bit 1 of SEQ_STATUS = seq_done)
    while ((REG_SEQ_STATUS & 0x02) == 0) {
        // Wait sequence completion
    }

    // Freeze tiles: switch sw_profile_id to Profile 1 (OFF) with sync pulse
    REG_CFG_CTRL = (1 << 4) | 0x01;
    wait_cycles(5);

    // Read back signature from Tile Config Bridge
    uint32_t xor_sig = REG_CFG_SIG_XOR;
    REG_SYS_SIG_OUT = (uint8_t)(xor_sig & 0xFF);

    // In Scenario 1, identical std tiles match expected non-zero behavior
    uint32_t sig0 = 0;
    uint32_t sig1 = 0;
    REG_CFG_SIG_SEL = 0;
    sig0 = REG_CFG_SIG_DATA;
    REG_CFG_SIG_SEL = 1;
    sig1 = REG_CFG_SIG_DATA;

    // Check validity
    uint8_t ok = 1;
    if (scenario == 1) {
        if (sig0 == 0 || sig0 != sig1) {
            ok = 0;
        }
    }

    // Write completion status to sys_ctrl
    // bit[0] = scenario_done (1)
    // bit[1] = sig_ok
    REG_SYS_STATUS = (ok ? 0x03 : 0x01);

    // Halt loop
    while (1) {
        wait_cycles(10);
    }

    return 0;
}
