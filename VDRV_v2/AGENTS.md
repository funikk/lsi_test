# VDRV_v2 Subproject Reference Guide (RTL Power-Gating Model)

This project is a multi-block ASIC testbed for RISC-V CPU and AES continuous load stimulation designed to study transient voltage drop ($di/dt$ IR-drop).

---

## 1. Directory Structure & Documentation Matrix

```text
VDRV_v2/
├── AGENTS.md                          # Subproject reference guide (this file)
├── Makefile                           # Automated build & sim & PnR targets
├── docs/                              # Project documentation tree
│   ├── system_architecture/           # System Architecture (System Architect)
│   │   ├── spec_top.md                # Top-level specification & memory map
│   │   └── architecture_candidates.md # Dual-mode hybrid architecture spec
│   ├── logic_design/                  # Logic Design Specs (Logic Design Lead)
│   │   ├── uart_ctrl/spec.md          # UART controller spec (Newly Developed)
│   │   ├── load_sequencer/spec.md     # Load sequencer spec (Newly Developed)
│   │   ├── picorv32_cpu/spec.md       # Reused from cpu_aes_prng_test
│   │   ├── aes_core/spec.md           # Reused from aes_prng_test
│   │   ├── lfsr_prng/spec.md          # Reused from aes_prng_test
│   │   └── aes_dma_subsys/spec.md     # Reused from cpu_aes_prng_test
│   ├── verification/                  # Verification Plans & Reports (Verification Lead)
│   │   ├── uart_ctrl/
│   │   │   ├── test_plan.md           # UART verification plan
│   │   │   └── verification_report.md # Simulation execution report
│   │   └── load_sequencer/
│   │       ├── test_plan.md           # Load sequencer verification plan
│   │       └── verification_report.md # Simulation execution report
│   ├── firmware/                      # Firmware Specification (Firmware Lead)
│   │   └── spec_firmware.md           # Firmware MMIO map, ISR & main loop spec
├── blocks/                            # Sub-block source code
│   ├── uart_ctrl/                     # UART RX/TX & packet parser
│   └── load_sequencer/                # 0.5us timer & 16-step sequence table
├── top/                               # Top-level integration (RTL & Testbenches)
│   ├── rtl/                           # Synthesizable VDRV_v2_core & VDRV_v2_top
│   └── tb/                            # System co-simulation testbench
└── firmware/                          # C/Assembly firmware source code
```

---

## 2. Key Documentation Links

### System Architecture
*   [Top-Level Specification (docs/system_architecture/spec_top.md)](docs/system_architecture/spec_top.md): Memory map, top I/O ports, and block diagram.
*   [Architecture Candidates (docs/system_architecture/architecture_candidates.md)](docs/system_architecture/architecture_candidates.md): Candidate C dual-mode hybrid design rationale.

### Logic Design Specs
*   [UART Control Spec (docs/logic_design/uart_ctrl/spec.md)](docs/logic_design/uart_ctrl/spec.md): Newly developed UART RX/TX & packet parser.
*   [Load Sequencer Spec (docs/logic_design/load_sequencer/spec.md)](docs/logic_design/load_sequencer/spec.md): Newly developed 0.5us tick timer & sequence RAM table.
*   [PicoRV32 CPU Spec (docs/logic_design/picorv32_cpu/spec.md)](docs/logic_design/picorv32_cpu/spec.md): Reused from `cpu_aes_prng_test`.
*   [AES Core Spec (docs/logic_design/aes_core/spec.md)](docs/logic_design/aes_core/spec.md): Reused from `aes_prng_test`.
*   [LFSR PRNG Spec (docs/logic_design/lfsr_prng/spec.md)](docs/logic_design/lfsr_prng/spec.md): Reused from `aes_prng_test`.
*   [AES-DMA Subsystem Spec (docs/logic_design/aes_dma_subsys/spec.md)](docs/logic_design/aes_dma_subsys/spec.md): Reused from `cpu_aes_prng_test`.

### Verification Plans & Reports
*   [Top System Test Plan (docs/verification/top/test_plan.md)](docs/verification/top/test_plan.md)
*   [Top System Verification Report (docs/verification/top/verification_report.md)](docs/verification/top/verification_report.md)
*   [UART Test Plan (docs/verification/uart_ctrl/test_plan.md)](docs/verification/uart_ctrl/test_plan.md)
*   [UART Verification Report (docs/verification/uart_ctrl/verification_report.md)](docs/verification/uart_ctrl/verification_report.md)
*   [Load Sequencer Test Plan (docs/verification/load_sequencer/test_plan.md)](docs/verification/load_sequencer/test_plan.md)
*   [Load Sequencer Verification Report (docs/verification/load_sequencer/verification_report.md)](docs/verification/load_sequencer/verification_report.md)

### Firmware & Physical Implementation
*   [Firmware Specification (docs/firmware/spec_firmware.md)](docs/firmware/spec_firmware.md): ISR vector, MMIO map, and C driver execution flow.
*   [AES Power Manager Spec (docs/logic_design/aes_power_manager/spec.md)](docs/logic_design/aes_power_manager/spec.md): RTL power-state and isolation model.

---

## 3. Automation Commands (Makefile)

```bash
# Clean temporary build/simulation artifacts
make clean

# Run block-level unit simulations
make BLOCK=uart_ctrl block_sim
make BLOCK=load_sequencer block_sim

# Run Verilator lint checks
make lint

# Run pre-synthesis structural check
make presynth_check

# Run top-level system co-simulation
make top_sim

# Execute PnR flow via LibreLane
make pnr

# Display PnR QoR phase metrics
make pnr_qor
```
