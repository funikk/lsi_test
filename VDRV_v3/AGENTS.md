# Multi-Developer Subproject: VDRV_v3

This directory (`VDRV_v3/`) is a multi-developer parallel RTL design subproject structure supporting isolated sub-block sandbox development and top-level system integration.

## 0. Purpose & Status

VDRV_v3 is the scaled-up EM/IR analysis tool testbench (target: 100k-1M instances in a commercial PDK, analysis-only, no tapeout).
Key features: parameterized load-tile array (`TILE_ROWS` x `TILE_COLS` + heterogeneous edge column), one power domain per tile row with two-stage (trickle/main) power-switch control, per-tile cycle-accurate pattern generators, ICG-based clock gating, EM stress structures, and pin-selected self-running scenarios with marker/signature outputs.

*   [Top-Level Specification (docs/system_architecture/spec_top.md)](docs/system_architecture/spec_top.md): Authoritative spec (Japanese). Section 12 defines the implementation phases.
*   [Architecture Decision Record (docs/system_architecture/architecture_candidates.md)](docs/system_architecture/architecture_candidates.md)

Status: Phase 1-4 complete (RTL blocks, top integration, firmware scenarios, system co-simulation verified). Phase 5 implemented (commercial UPF/SDC/cell mapping templates in `impl/commercial/`, local LibreLane PnR flow prepared in `pnr/`).

Key references:
*   [Top-Level Specification (docs/system_architecture/spec_top.md)](docs/system_architecture/spec_top.md): System architecture and scenario specifications.
*   [Commercial Implementation Guide (impl/commercial/README.md)](impl/commercial/README.md): UPF, SDC, and cell mapping instructions for 40nm PDK.
*   [PnR Configuration (pnr/config.json)](pnr/config.json): LibreLane physical design configuration.
*   [PnR Timing Constraints (pnr/constraint.sdc)](pnr/constraint.sdc): OpenROAD STA constraints.

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
│   ├── rtl/                   # PDK-abstracted wrappers (vdrv_icg, vdrv_sram_wrap, etc.)
│   └── tb/                    # Testbench models (vdrv_pwr_switch_model)
├── docs/                      # Central technical specifications and domain plans
├── blocks/                    # Independent sub-block sandboxes
├── top/                       # Top Integration Layer (VDRV_v3_core, VDRV_v3_top)
├── impl/commercial/           # Commercial 40nm PDK templates (UPF, SDC, cell_map.md)
└── pnr/                       # Local PnR flow (LibreLane OpenROAD)
```

---

## 2. Developer Workflow & Automation Commands

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

# 5. Run full-chip synthesis (Yosys)
make top_syn

# 6. Run physical design (PnR) flow using LibreLane
make pnr

# 7. Generate PnR QoR & phase report
make pnr_qor

# 8. Clean temporary simulation/synthesis outputs
make clean
```
