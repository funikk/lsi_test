# CPU + AES/PRNG Motif Circuit Subproject Guide (`cpu_aes_prng_test`)

This directory (`cpu_aes_prng_test/`) contains an integrated LSI design combining a 32-bit RISC-V CPU core (PicoRV32), a shared data SRAM (`dmem`), an instruction RAM (`imem`), and an AES-128 / LFSR PRNG DMA subsystem for dynamic IR-Drop power grid stress testing.

---

## 1. Directory Structure

```text
cpu_aes_prng_test/
├── AGENTS.md                  # Project overview and developer guide (this file)
├── Makefile                   # Top-level build & verification automation Makefile
├── docs/                      # Sub-block technical specifications & licenses
│   ├── spec_top.md            # Top-level architecture, interconnect, and memory map
│   ├── spec_picorv32_cpu.md   # PicoRV32 RISC-V CPU core specification
│   ├── spec_aes_dma_subsys.md # AES-DMA subsystem & MMIO register map specification
│   ├── spec_lfsr_prng.md      # 128-bit LFSR PRNG specification
│   ├── spec_aes_core.md       # Iterative AES-128 encryption core & S-box specification
│   ├── spec_memories.md       # Instruction RAM (imem) & Shared Data SRAM (dmem) specification
│   └── licenses_and_citations.md # External IP licenses & citation documentation
├── rtl/                       # Synthesizable RTL Verilog source files
│   ├── picorv32.v             # PicoRV32 32-bit RISC-V CPU core
│   ├── aes_sbox.v             # Standard AES S-box lookup logic
│   ├── aes_core.v             # Iterative AES-128 core with 20 parallel S-boxes
│   ├── lfsr_prng_ctrl.v       # 128-bit LFSR PRNG (seed load & CPU readback)
│   ├── aes_dma_subsys.v       # MMIO, DMA engine, line buffer, and load mode logic
│   ├── imem.v                 # Instruction Memory (loading firmware.hex)
│   ├── dmem.v                 # Single-port Data SRAM (shared between CPU & DMA)
│   └── cpu_aes_prng_top.v     # Top-level module connecting CPU, memories, & subsystem
├── firmware/                  # RISC-V C Firmware Build Infrastructure
│   ├── main.c                 # C source code controlling all 5 requirements
│   ├── start.S                # RISC-V startup assembly (sets sp, calls main)
│   ├── sections.lds           # Linker script for RV32I memory placement
│   ├── bin2hex.py             # Converts binary elf output to 32-bit Verilog hex
│   ├── Makefile               # Standalone Makefile for firmware compilation
│   └── gen_firmware.py        # Python wrapper script calling GCC & bin2hex
├── tb/                        # Testbench
│   └── tb_cpu_aes_prng.v      # System testbench (supports RTL & Gate-Level Simulation)
├── sim/                       # Simulation output directory (VCD waves, executables)
├── syn/                       # Synthesis output directory (Yosys scripts, netlists)
│   └── presynth_check.ys      # Pre-synthesis fast quality check script (0.7s)
└── gls/                       # Gate-Level Simulation output directory
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
# 1. Compile firmware standalone
make firmware

# 2. Run Verilator lint check on RTL (strict multi-driver checking)
make lint

# 3. Run ultra-fast Yosys Pre-Synthesis Check (0.7s, catches ALDFFE/Multi-driver errors)
make presynth_check

# 4. Run Icarus Verilog RTL simulation
make rtl_sim

# 5. Run Yosys logic synthesis
make syn

# 6. Run Gate-Level Simulation (GLS)
make gls_sim

# 7. Run PnR flow (100MHz, sky130_fd_sc_hs)
make pnr

# 8. Report phase-by-phase QoR & runtime table (hh:mm:ss format)
make pnr_qor

# 9. Run all verification steps
make all

# 10. Clean temporary files
make clean
```

---

## 5. Technical Specifications Link Index

For detailed sub-block designs, refer to the documents in `docs/`:
- [Top-Level Architecture & Memory Map Guide](docs/spec_top.md)
- [PicoRV32 RISC-V CPU Core Specification](docs/spec_picorv32_cpu.md)
- [AES-DMA Subsystem & MMIO Register Specification](docs/spec_aes_dma_subsys.md)
- [128-bit LFSR PRNG Specification](docs/spec_lfsr_prng.md)
- [Iterative AES-128 Encryption Core Specification](docs/spec_aes_core.md)
- [Instruction RAM (imem) & Shared Data SRAM (dmem) Specification](docs/spec_memories.md)
