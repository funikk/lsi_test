---
name: new-circuit-project
description: >
  Creates a new circuit design subproject with the standard industry directory
  structure (rtl/, tb/, sim/, syn/, gls/, docs/), Makefile, and template files for the LSI Testbed.
  Use when the user asks to "create a new circuit project", "add a new Verilog module",
  "setup a new subproject", or similar.
---

# New Circuit Project Creator

## Overview
This skill automates the setup of a new Verilog/SystemVerilog circuit design subproject within the `lsi_test` repository. It creates a standardized directory structure (`docs/`, `rtl/`, `tb/`, `sim/`, `syn/`, `gls/`) along with all necessary automation files (`Makefile`, `syn/run_synth.ys`, `syn/presynth_check.ys`, `AGENTS.md`, and starter RTL/testbench files).

> [!NOTE]
> Physical design (PnR) setup under `librelane_designs/` is managed separately by the `pnr-setup` skill.

## Quick Start

To create a new subproject named `my_fifo`:

```bash
uv run python3 .agents/skills/new-circuit-project/scripts/create_new_project.py --name my_fifo
```

After creation, navigate to `my_fifo/` and verify all verification phases:

```bash
cd my_fifo
make lint           # Verilator lint check
make presynth_check # Pre-synthesis AST check
make rtl_sim        # RTL simulation
make syn            # Yosys logic synthesis (generates my_fifo_syn.v)
make gls_sim        # Gate-Level simulation
```

## Generated Project Directory Structure

```text
<project_name>/
├── AGENTS.md                 # Subproject reference guide and verification commands
├── Makefile                  # Automation targets (lint, presynth_check, rtl_sim, syn, gls_sim, clean)
├── docs/
│   ├── system_architecture/  # System architecture specs (`spec_top.md`, `architecture_candidates.md`)
│   ├── logic_design/<project_name>/ # Block-level logic specs (`spec.md`)
│   ├── verification/<project_name>/ # Block-level test plans and verification reports (`test_plan.md`)
│   ├── firmware/             # Firmware specs, MMIO maps, driver docs (`spec_firmware.md`)
│   └── backend/              # Physical design & PnR QoR reports (`pnr_qor_report.md`)
├── rtl/
│   └── <project_name>.v      # Synthesizable RTL module template
├── tb/
│   └── tb_<project_name>.v   # Testbench template (clock gen, VCD dumping, success check)
├── sim/                      # Output directory for RTL simulation artifacts
├── syn/
│   ├── presynth_check.ys    # Pre-synthesis AST check script
│   └── run_synth.ys         # Yosys synthesis script (outputs <project_name>_syn.v)
└── gls/                      # Output directory for Gate-Level Simulation artifacts
```

## Utility Scripts

### `create_new_project.py`

| Parameter | Required | Description |
| :--- | :---: | :--- |
| `--name`, `-n` | **Yes** | Name of the project/module (e.g. `mac_array`, `counter`) |
| `--force` | No | Overwrite existing project directory if present |

Example:
```bash
uv run python3 .agents/skills/new-circuit-project/scripts/create_new_project.py -n my_alu --force
```

## Post-Setup Workflow

1. Edit `rtl/<project_name>.v` to implement your custom synthesizable RTL logic.
2. Update `tb/tb_<project_name>.v` with test vectors and verification assertions.
3. Run `make all` or individual make targets to verify linting, simulation, and synthesis.
4. (Optional) To configure physical design (PnR) for LibreLane, run the `pnr-setup` skill.

## Common Mistakes

1. **Netlist Naming Mismatch**:
   Always ensure the Yosys synthesis script `run_synth.ys` outputs `<project_name>_syn.v` (ending in `_syn.v`), which matches the root `.gitignore` pattern `*/syn/*_syn.v`.
2. **Hardcoded Absolute Paths**:
   Never use absolute paths in Makefiles or scripts. Always use relative paths from the subproject directory.

