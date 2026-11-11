# VDRV_v1a Subproject Reference Guide (Voltage Drop on RISC-V v1a)

`VDRV_v1a` is a multi-block ASIC testbed for RISC-V CPU and dual-engine hardware load stimulation (Systolic MAC Array + Reed-Solomon mixed Parallel CRC Channels) designed to study dynamic voltage drops (IR-drop) and high $di/dt$ transient currents using open-source EDA tools.

---

## 1. Directory Structure

```text
VDRV_v1a/
├── AGENTS.md                          # Subproject reference guide (this file)
├── Makefile                           # Modular dispatch Makefile for blocks, top, and PnR
├── common/                            # Shared headers and sync cells
│   ├── AGENTS.md
│   └── rtl/
│       ├── defines.vh                 # Shared global macros and bus widths
│       ├── reset_sync.v               # 2-stage asynchronous reset synchronizer
│       ├── imem.v                     # 8KB Instruction Memory ROM (reads firmware.hex)
│       └── dmem.v                     # 512B Shared Data SRAM
├── blocks/                            # Sub-block sandboxes
│   ├── lfsr_prng/                     # 128-bit LFSR PRNG controller
│   ├── mac_load_core/                 # 5x4 Systolic MAC Array stress core
│   ├── crc_load_core/                 # 4-channel parallel CRC with GF(2^8) RS mixer
│   ├── load_dma_subsys/               # Load DMA Subsystem with MMIO interface
│   ├── picorv32_cpu/                  # RV32I PicoRV32 CPU core
│   ├── load_sequencer/                # 16-step sequence memory & 0.5us step timer
│   └── uart_ctrl/                     # 115200 bps UART RX/TX and packet parser
├── top/                               # System integration layer
│   ├── AGENTS.md
│   ├── filelist.f                     # Flat file list for top simulation & synthesis
│   ├── Makefile                       # Top integration Makefile
│   ├── rtl/
│   │   ├── VDRV_v1a_core.v            # Core ASIC logic (PnR boundary module)
│   │   └── VDRV_v1a_top.v             # Full chip wrapper including IMEM & DMEM
│   ├── tb/
│   │   └── tb_VDRV_v1a_top.v          # HW/SW co-simulation system testbench
│   └── sim/                           # Simulation outputs (top_tb.vvp, VCD)
├── firmware/                          # Bare-metal RISC-V C/Assembly firmware
│   ├── Makefile
│   ├── start.S                        # CRT0 startup assembly & trap handler
│   ├── main.c                         # Self-test sequence & load polling loop
│   ├── sections.lds                   # Linker script
│   └── bin2hex.py                     # Binary to Verilog hex memory file converter
├── pnr/                               # LibreLane / OpenROAD Physical Design setup
│   ├── config.json                    # OpenROAD PnR configuration
│   ├── constraint.sdc                 # SDC timing constraints (100 MHz target)
│   └── pin_order.cfg                  # Die boundary pin placement configuration
├── sim_vcs/                           # Synopsys VCS simulation & Verdi debug environment
│   ├── Makefile                       # VCS build and run targets
│   ├── vcs_filelist.f                 # Flat VCS compile filelist (+incdir+)
│   └── run_vcs.sh                     # VCS execution script
├── fc/                                # Synopsys Fusion Compiler (RTL-to-GDSII) environment
│   ├── Makefile                       # FC stage-by-stage & batch targets
│   ├── fc_env.sh                      # PDK & library environment variables
│   ├── inputs/                        # SDC & Pin constraint scripts
│   ├── scripts/                       # Modular execution Tcl scripts (00..09, run_all)
│   ├── reports/                       # Timing, area, power, and QoR reports
│   └── outputs/                       # DEF, SPEF, GDSII, and Verilog netlists
└── docs/                              # Technical specifications and verification reports
    ├── system_architecture/
    │   ├── spec_top.md                # Top architecture, block diagram, and memory map
    │   └── architecture_candidates.md # Dual-engine load generation & sequencer architecture
    ├── firmware/
    │   └── spec_firmware.md           # Firmware MMIO map, boot sequence, and self-test
    ├── backend/
    │   └── pnr_qor_report.md          # PnR QoR targets, constraints, and signoff criteria
    └── verification/
        └── top/
            ├── test_plan.md           # Top-level verification plan and test matrix
            └── verification_report.md # Simulation execution report (PASS)
```

---

## 2. Key Documentation Links

### System Architecture
*   [Top-Level Specification (docs/system_architecture/spec_top.md)](docs/system_architecture/spec_top.md): System architecture, Mermaid block diagram, memory map, and I/O pin tables.
*   [Architecture Candidates (docs/system_architecture/architecture_candidates.md)](docs/system_architecture/architecture_candidates.md): Rationale for dual-engine load generation (MAC + CRC) and hybrid sequencing.

### Firmware & Physical Design
*   [Firmware Specification (docs/firmware/spec_firmware.md)](docs/firmware/spec_firmware.md): MMIO register definitions, self-test flow, and cooperative polling loop.
*   [Backend PnR QoR Report (docs/backend/pnr_qor_report.md)](docs/backend/pnr_qor_report.md): PnR configuration, SDC timing constraints, pin placement, and signoff criteria.
*   [Commercial EDA User Guide (docs/commercial_eda_guide.md)](docs/commercial_eda_guide.md): Guide for running VCS simulation and Fusion Compiler physical implementation.
*   [PnR Configuration (pnr/config.json)](pnr/config.json)
*   [SDC Timing Constraints (pnr/constraint.sdc)](pnr/constraint.sdc)
*   [Die Pin Order (pnr/pin_order.cfg)](pnr/pin_order.cfg)
*   [Fusion Compiler Scripts (fc/scripts/)](fc/scripts/)
*   [VCS Simulation Setup (sim_vcs/)](sim_vcs/)

### Verification Plans & Reports
*   [Top System Test Plan (docs/verification/top/test_plan.md)](docs/verification/top/test_plan.md): Test scenarios, pass/fail criteria, and simulation matrix.
*   [Top System Verification Report (docs/verification/top/verification_report.md)](docs/verification/top/verification_report.md): Execution logs and verification signoff.

---

## 3. Automation Commands (Makefile)

From the `VDRV_v1a/` root directory:

```bash
# 1. Run unit simulations for ALL blocks in parallel
make -j unit_sim

# 2. Run static lint checks across all modules
make lint

# 3. Run fast Yosys pre-synthesis AST & quality checks
make presynth_check

# 4. Run top-level HW/SW co-simulation (iverilog)
make top_sim

# 5. Run full chip logic synthesis (yosys)
make top_syn

# 6. Run physical design (PnR) flow via LibreLane (OpenROAD)
make pnr

# 7. Generate phase-by-phase QoR & runtime report
make pnr_qor

# 8. Run top-level RTL simulation with Synopsys VCS
make vcs_sim

# 9. Launch Verdi GUI for RTL waveform analysis
make vcs_verdi

# 10. Run Gate-Level Simulation (GLS) with Synopsys VCS
make vcs_gls_sim

# 11. Launch Verdi GUI for GLS waveform analysis
make vcs_gls_verdi

# 12. Run full RTL-to-GDSII flow with Synopsys Fusion Compiler
make fc_all

# 13. Run Logic Synthesis with Fusion Compiler
make fc_synth

# 14. Launch Fusion Compiler GUI
make fc_gui

# 15. Clean temporary files
make clean
```
