# Multi-Developer Subproject: __PROJECT_NAME__

This directory (`__PROJECT_NAME__/`) is a multi-developer parallel RTL design subproject structure supporting isolated sub-block sandbox development and top-level system integration.

---

## 1. Directory Structure

```text
__PROJECT_NAME__/
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
    │   └── __PROJECT_NAME___top.v # Top wrapper module connecting sub-blocks
    ├── tb/
    │   └── tb___PROJECT_NAME___top.v # Full system testbench
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
