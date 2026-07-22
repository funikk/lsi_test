# CPU + AES/PRNG Motif Circuit Subproject Guide (`cpu_aes_prng_test`)

This directory (`cpu_aes_prng_test/`) contains an integrated LSI design combining a 32-bit RISC-V CPU core (PicoRV32), a shared data SRAM (`dmem`), an instruction RAM (`imem`), and an AES-128 / LFSR PRNG DMA subsystem for dynamic IR-Drop power grid stress testing.
It is organized into the **Multi-Block Parallel Development Architecture** (`blocks/`, `common/`, `top/`).

---

## 1. Directory Structure

```text
cpu_aes_prng_test/
├── AGENTS.md                  # Project overview and developer guide (this file)
├── Makefile                   # Top-level dispatch build & verification Makefile
├── blocks/                    # Independent sub-block sandboxes
│   ├── aes_core/              # Sub-block 1: AES-128 Encryption Core (Iterative + S-box)
│   │   ├── rtl/ (aes_core.v, aes_sbox.v)
│   │   ├── tb/  (tb_aes_core.v - FIPS-197 unit testbench)
│   │   ├── Makefile, filelist.f, AGENTS.md
│   │   └── sim/, syn/
│   ├── lfsr_prng/             # Sub-block 2: 128-bit LFSR PRNG Generator
│   │   ├── rtl/ (lfsr_prng_ctrl.v)
│   │   ├── tb/  (tb_lfsr_prng_ctrl.v - Seed load & shift unit testbench)
│   │   ├── Makefile, filelist.f, AGENTS.md
│   │   └── sim/, syn/
│   ├── aes_dma_subsys/        # Sub-block 3: AES-128 DMA Subsystem & MMIO
│   │   ├── rtl/ (aes_dma_subsys.v)
│   │   ├── tb/  (tb_aes_dma_subsys.v - MMIO & DMA unit testbench)
│   │   ├── Makefile, filelist.f, AGENTS.md
│   │   └── sim/, syn/
│   └── picorv32_cpu/          # Sub-block 4: PicoRV32 RISC-V CPU Core
│       ├── rtl/ (picorv32.v)
│       ├── tb/  (tb_picorv32.v - Memory fetch handshake unit testbench)
│       ├── Makefile, filelist.f, AGENTS.md
│       └── sim/, syn/
├── common/                    # Shared modules & memory primitives
│   └── rtl/ (imem.v, dmem.v, reset_sync.v)
├── docs/                      # Sub-block technical specifications & licenses
│   ├── spec_top.md            # Top-level architecture, interconnect, and memory map
│   ├── spec_picorv32_cpu.md   # PicoRV32 RISC-V CPU core specification
│   ├── spec_aes_dma_subsys.md # AES-DMA subsystem & MMIO register map specification
│   ├── spec_lfsr_prng.md      # 128-bit LFSR PRNG specification
│   ├── spec_aes_core.md       # Iterative AES-128 encryption core specification
│   ├── spec_memories.md       # Instruction RAM & Shared Data SRAM specification
│   └── licenses_and_citations.md # External IP licenses
├── firmware/                  # RISC-V C Firmware Build Infrastructure
│   ├── main.c                 # C source code controlling test sequence
│   ├── start.S, sections.lds, bin2hex.py, Makefile, gen_firmware.py
└── top/                       # System Integration & Full-Chip Synthesis
    ├── rtl/ (cpu_aes_prng_core.v, cpu_aes_prng_top.v)
    ├── tb/  (tb_cpu_aes_prng.v - System integration testbench)
    ├── Makefile, filelist.f
    └── sim/, syn/, gls/
```

---

## 2. Key Architecture & Features

1. **PicoRV32 RISC-V Core (RV32I)**: Harvard split bus architecture. Instruction requests (`mem_instr == 1`) read `imem.v`; data requests (`mem_instr == 0`) access `dmem.v` or MMIO registers.
2. **MMIO Register Control (`0x8000_0000`)**:
   - `0x00`: `CTRL` (bit[0]: `DMA_START`, bit[1]: `LOAD_MODE_EN`, bit[2]: `SEED_LOAD`)
   - `0x04`: `STATUS` (bit[0]: `DMA_BUSY`, bit[1]: `DMA_DONE`, bit[2]: `AES_BUSY`)
   - `0x10 - 0x1C`: `AES_KEY[0..3]` (128-bit Key writable by CPU)
   - `0x20 - 0x2C`: `PRNG_SEED[0..3]` (128-bit Seed writable by CPU)
   - `0x30 - 0x3C`: `PRNG_DATA[0..3]` (128-bit PRNG output readable by CPU)
   - `0x40`: `DMA_SRC_ADDR`, `0x44`: `DMA_DST_ADDR`, `0x48`: `DMA_LEN`
3. **SRAM DMA Data Encryption**: CPU sets addresses & length, triggers DMA. DMA reads DMEM -> AES Local Buffer -> AES Core -> writes DMEM encrypted output.
4. **Continuous PRNG IR-Drop Stress Mode (`LOAD_MODE_EN`)**: PRNG feeds AES continuously every 12 clock cycles with 20 parallel S-boxes for maximum dynamic power grid stress generation.

---

## 3. Firmware Build & Compilation

Firmware is written in C (`firmware/main.c`) and compiled with `riscv64-unknown-elf-gcc`:

```bash
# Compile firmware standalone
cd firmware
make

# Clean firmware build artifacts
make clean
```

---

## 4. Automation Commands

```bash
# 1. Run unit simulations across ALL sub-blocks sequentially
make unit_sim

# 2. Run unit simulations across ALL sub-blocks in PARALLEL (Multi-core)
make -j unit_sim

# 3. Run unit simulation for target sub-block
make BLOCK=aes_core block_sim
make BLOCK=lfsr_prng block_sim
make BLOCK=aes_dma_subsys block_sim
make BLOCK=picorv32_cpu block_sim

# 4. Run Out-of-Context synthesis for target sub-block
make BLOCK=aes_core block_syn

# 5. Run system integration simulation (Top-level RTL + Firmware execution)
make top_sim
# (or alias: make rtl_sim)

# 6. Run full-chip logic synthesis
make top_syn
# (or alias: make syn)

# 7. Run Gate-Level Simulation (GLS)
make gls_sim

# 8. Run Verilator lint check across all blocks and top
make lint

# 9. Run Yosys pre-synthesis AST check across all blocks and top
make presynth_check

# 10. Run PnR flow (100MHz, sky130_fd_sc_hs)
make pnr

# 11. Report phase-by-phase QoR & runtime table (hh:mm:ss format)
make pnr_qor

# 12. Clean temporary files in all blocks and top
make clean
```
