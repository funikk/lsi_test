---
name: new-multi-block-project
description: >
  Creates a new multi-developer parallel circuit design subproject using template copying
  (resources/template_project) and placeholder substitution. Also supports adding individual
  standalone sub-blocks (resources/template_block).
  Use when the user asks to "create a multi-block project", "setup a multi-developer project",
  "add a sub-block", or similar.
---

# New Multi-Block Project & Sub-Block Creator

## Overview
This skill automates the setup of multi-developer parallel circuit design projects and individual sub-block sandboxes within the repository. It uses static template directories (`resources/template_project` and `resources/template_block`) and simple shell-based placeholder substitution.

## Documentation Structure
The project generates the following standardized role-based documentation directory hierarchy under `docs/`:
- `docs/system_architecture/` : System architecture specs (`spec_top.md`, `architecture_candidates.md`)
- `docs/logic_design/<block_name>/` : Block-level logic specs (`spec.md`)
- `docs/verification/<block_name>/` : Block-level test plans and verification reports (`test_plan.md`)
- `docs/firmware/` : Firmware specs, MMIO maps, driver docs (`spec_firmware.md`)
- `docs/backend/` : Physical design & PnR QoR reports (`pnr_qor_report.md`)

When adding a sub-block, its logic design and verification documents will be automatically created under this central `docs/` structure.

## Quick Start

### 1. Create a New Multi-Developer Project
To instantiate a new project named `my_multi_project`:

```bash
bash .agents/skills/new-multi-block-project/scripts/create_multi_block_project.sh --name my_multi_project
```

### 2. Add an Independent Sub-Block Sandbox to an Existing Project
To add a new sub-block named `alu_core` to `my_multi_project`:

```bash
bash .agents/skills/new-multi-block-project/scripts/add_sub_block.sh --project my_multi_project --block alu_core
```

---

## Developer Workflow & Verification

After generating a project or adding a sub-block, navigate to your project directory:

```bash
cd my_multi_project
make -j unit_sim                    # Run unit tests across all sub-blocks in parallel
make BLOCK=alu_core block_sim       # Run unit test for target sub-block
make top_sim                        # Run top-level system integration simulation
make lint                           # Run Verilator lint across all blocks and top
make presynth_check                 # Run Yosys pre-synthesis AST check across all modules
make clean                          # Clean temporary simulation/synthesis artifacts
```

---

## Directory Structure

```text
.agents/skills/new-multi-block-project/
├── SKILL.md
├── resources/
│   ├── template_project/           # Full project directory template
│   └── template_block/             # Standalone sub-block directory template
└── scripts/
    ├── create_multi_block_project.sh  # Project generator script
    └── add_sub_block.sh               # Sub-block generator script
```

## Utility Scripts Reference

### `create_multi_block_project.sh`
| Parameter | Required | Description |
| :--- | :---: | :--- |
| `-n`, `--name` | **Yes** | Name of the multi-developer project (e.g. `multi_block_test`) |
| `--force` | No | Overwrite destination directory if present |

### `add_sub_block.sh`
| Parameter | Required | Description |
| :--- | :---: | :--- |
| `-p`, `--project` | **Yes** | Path or name of the target multi-developer project |
| `-b`, `--block` | **Yes** | Name of the new sub-block (e.g. `alu_core`, `decoder`) |
| `--force` | No | Overwrite block directory if present |
