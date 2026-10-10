# Multi-Developer Subproject: VDRV_v3

This directory (`VDRV_v3/`) is a multi-developer parallel RTL design subproject structure supporting isolated sub-block sandbox development and top-level system integration.

## 0. Purpose & Status

VDRV_v3 is the scaled-up EM/IR analysis tool testbench (target: 100k-1M instances in a commercial PDK, analysis-only, no tapeout).
Key features: parameterized load-tile array (`TILE_ROWS` x `TILE_COLS` + heterogeneous edge column), one power domain per tile row with two-stage (trickle/main) power-switch control, per-tile cycle-accurate pattern generators, ICG-based clock gating, EM stress structures, and pin-selected self-running scenarios with marker/signature outputs.

*   [Top-Level Specification (docs/system_architecture/spec_top.md)](docs/system_architecture/spec_top.md): Authoritative spec (Japanese). Section 12 defines the implementation phases.
*   [Architecture Decision Record (docs/system_architecture/architecture_candidates.md)](docs/system_architecture/architecture_candidates.md)

Status: Phase 0 (spec written). Reused blocks copied from `VDRV_v2`: `aes_core`, `lfsr_prng`, `picorv32_cpu`, `uart_ctrl`, `load_sequencer` (to be extended), `aes_power_manager` (reference only; to be replaced by `pwr_manager`). `template_block` and `top/rtl/VDRV_v3_top.v` are skeleton placeholders.

Rules:
*   Keep RTL PDK-independent. PDK-specific cells (SRAM, ICG, isolation, power switch) MUST be instantiated only through wrappers in `common/rtl/` (`vdrv_sram_wrap`, `vdrv_icg`, `vdrv_iso_and`).
*   All tile-boundary inputs/outputs MUST be registered.
*   Power-switch acks are modeled in testbenches only (`vdrv_pwr_switch_model`).

---

## 1. Directory Structure

```text
VDRV_v3/
├── AGENTS.md                  # Project overview & developer guide
├── Makefile                   # Top dispatch Makefile (delegates tasks to blocks/ or top/)
├── common/                    # Shared assets across blocks
│   ├── AGENTS.md              # Rules for shared headers & bus definitions
│   └── rtl/
│       └── defines.vh         # Shared global parameters & macro definitions
├── docs/                      # Central technical specifications and domain plans
│   ├── AGENTS.md              # Documentation guidelines & subagent directory mapping
│   ├── system_architecture/   # System Architecture specs (managed by system_architect)
│   ├── logic_design/          # Interface & protocol specs (managed by logic_design)
│   ├── verification/          # Test & coverage plans (managed by logic_verification)
│   ├── backend/               # Floorplan, timing & PnR specs (managed by backend_design)
│   └── firmware/              # MMIO maps & driver specs (managed by firmware_design)
├── blocks/                    # Independent sub-block sandboxes (assigned per developer/agent)
│   └── template_block/        # Reference template for creating new sub-blocks
│       ├── AGENTS.md          # Sub-block developer guide
│       ├── filelist.f         # Sub-block file list
│       ├── rtl/               # Sub-block synthesizable Verilog source
│       ├── tb/                # Sub-block unit testbench
│       ├── sim/               # Isolated unit simulation output
│       ├── syn/               # Out-of-Context (OOC) block synthesis output
│       ├── docs/              # Sub-block technical specification
│       └── Makefile           # Standalone sub-block Makefile
└── top/                       # Top Integration Layer (System Integrator)
    ├── AGENTS.md              # System integration guide
    ├── filelist.f             # Top integration file list
    ├── rtl/
    │   └── VDRV_v3_top.v # Top wrapper module connecting sub-blocks
    ├── tb/
    │   └── tb_VDRV_v3_top.v # Full system testbench
    ├── sim/                   # System simulation output
    ├── syn/                   # Full chip synthesis output
    └── Makefile               # Integration Makefile
```

---

## 2. Developer Workflow & Automation Commands

### Sub-Block Sandbox Development
Developers work independently in `blocks/<block_name>/`:
```bash
cd blocks/template_block
make unit_sim

# Or from project root:
make BLOCK=template_block block_sim
```

### Root Parallel Verification Commands
The top dispatch Makefile supports parallel execution across all sub-blocks:

```bash
# 1. Run unit simulations for ALL blocks in parallel
make -j unit_sim

# 2. Run Verilator lint across all blocks and top module
make lint

# 3. Run fast Yosys pre-synthesis AST & quality check across all modules
make presynth_check

# 4. Run top-level integrated system simulation
make top_sim

# 5. Clean temporary simulation/synthesis outputs across all blocks and top
make clean
```
