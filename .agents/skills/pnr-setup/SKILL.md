---
name: pnr-setup
description: >-
  Use when the user asks to set up, configure, or prepare the PnR execution environment for a Verilog/SystemVerilog RTL module, or when integrating a new module into physical design. Generates librelane_designs/<module>/config.json, constraint.sdc, updates subproject Makefile with pnr (including --hide-progress-bar) and pnr_qor targets, updates AGENTS.md, and verifies RTL quality with pre-synthesis checks.
---

# PnR Design Setup Skill

## Overview

This skill automates the setup of the Physical Design (PnR) execution environment for any Verilog / SystemVerilog subproject within the `lsi_test` workspace using LibreLane.

It includes automated script execution via `setup_pnr.py` and enforces OpenROAD-compatible SDC timing constraints (`constraint.sdc`).

---

## Quick Start (Automated Script)

To automatically generate `librelane_designs/<MODULE_NAME>/config.json` and `constraint.sdc`:

```bash
uv run python3 .agents/skills/pnr-setup/scripts/setup_pnr.py --name <MODULE_NAME> --clk-period 10.0 --std-cell sky130_fd_sc_hd
```

---

## Input Parameters & Default Handling

When invoked, accept or determine the following parameters:

1. **`MODULE_NAME`** (Required): Target module name and subproject directory name (e.g., `counter`, `fifo_top`, `aes_prng_top`).
2. **`CLOCK_PERIOD`** (Optional, Default: `10.0` ns = 100MHz): Target clock period in nanoseconds.
3. **`CLOCK_PORT`** (Optional, Default: Auto-detected from RTL, fallback `clk`): Name of the top-level clock port.
4. **`STD_CELL_LIBRARY`** (Optional, Default: `sky130_fd_sc_hd`): Sky130 standard cell library (`sky130_fd_sc_hd` for High Density, `sky130_fd_sc_hs` for High Speed).
5. **`FP_CORE_UTIL`** (Optional, Default: `40` %): Target core area utilization.
6. **`PL_TARGET_DENSITY_PCT`** (Optional, Default: `45` %): Target placement density percentage.

> [!NOTE]
> If any optional parameter is omitted by the user, apply default values and explicitly list applied defaults in the summary report.

---

## Step-by-Step Execution Workflow

### Step 1: RTL Inspection & Pre-Synthesis Quality Check

1. Inspect top-level RTL file in `<MODULE_NAME>_test/rtl/` or `<MODULE_NAME>/rtl/` to confirm top-level module name, clock port, and Verilog sources.
2. Run pre-synthesis quality check:
   ```bash
   cd <MODULE_DIRECTORY> && make presynth_check
   ```
3. Auto-adjust parameters if minor differences exist, or report critical synthesis errors to the user.

---

### Step 2: Create `config.json` and `constraint.sdc`

Run the automation script or generate files under `librelane_designs/<MODULE_NAME>/`:

```bash
uv run python3 .agents/skills/pnr-setup/scripts/setup_pnr.py --name <MODULE_NAME> -c 10.0 -s sky130_fd_sc_hd
```

#### `librelane_designs/<MODULE_NAME>/config.json`
```json
{
    "DESIGN_NAME": "<MODULE_NAME>",
    "VERILOG_FILES": [
        "dir::../../<MODULE_DIR>/rtl/<file1>.v",
        "dir::../../<MODULE_DIR>/rtl/<file2>.v"
    ],
    "CLOCK_PERIOD": 10.0,
    "CLOCK_PORT": "clk",
    "CLOCK_NET": "ref::$CLOCK_PORT",
    "STD_CELL_LIBRARY": "sky130_fd_sc_hd",
    "STD_CELL_LIBRARY_OPT": "sky130_fd_sc_hd",
    "FP_PIN_ORDER_CFG": "dir::pin_order.cfg",
    "BASE_SDC_FILE": "dir::constraint.sdc",
    "pdk::sky130*": {
        "FP_CORE_UTIL": 40,
        "PL_TARGET_DENSITY_PCT": 45,
        "MAX_FANOUT_CONSTRAINT": 20
    }
}
```

> [!IMPORTANT]
> Always use `dir::` relative paths in `VERILOG_FILES`, `FP_PIN_ORDER_CFG`, and `BASE_SDC_FILE` to maintain project portability. Never use absolute paths (`/home/...`).

---

## Pin Placement Order Guidelines (`pin_order.cfg`)

To control the physical sides/edges (North, South, East, West) where I/O pin ports are placed on the die boundary, create `librelane_designs/<MODULE_NAME>/pin_order.cfg`:

```text
#N
clk
rst_n

#S
trap_out

#E
dmem_.*
out_.*

#W
imem_.*
in_.*
```

- **Side Identifiers**: `#N` (North / Top), `#S` (South / Bottom), `#E` (East / Right), `#W` (West / Left).
- **Regex Matching**: Use regular expressions (e.g. `dmem_.*`) to match bus signals.
- **Reference in `config.json`**: Add `"FP_PIN_ORDER_CFG": "dir::pin_order.cfg"`.

---

## SDC Timing Constraints Guidelines (OpenROAD Compatibility)

When creating or customizing `librelane_designs/<MODULE_NAME>/constraint.sdc`, adhere strictly to these rules:

### 1. Avoid `set_dont_touch` (OpenSTA Incompatibility)
- **Do NOT use `set_dont_touch`** in SDC files. OpenROAD's OpenSTA parser will throw a syntax error (`invalid command name "set_dont_touch"`).

### 2. Auto-Guide Physical Proximity using `set_max_delay`
- To force OpenROAD Placement engines to place 2-stage Flip-Flops (e.g. Reset Synchronizer cells) in physical proximity, set a tight `set_max_delay` constraint between them:
  ```tcl
  set_max_delay 2.0 -from [get_cells -hierarchical *u_reset_sync*u_dff1*] -to [get_cells -hierarchical *u_reset_sync*u_dff2*]
  ```

### 3. Handle Escaped Hierarchical Cell Names
- Yosys netlists escape hierarchical instance names with dots/backslashes (e.g., `\u_reset_sync.u_dff1 `). Always use wildcard pattern matching (`*u_reset_sync*u_dff1*`) in `-from` / `-to` arguments.

### 4. False Path for Asynchronous Inputs
- Set false paths for external asynchronous inputs (like reset):
  ```tcl
  set_false_path -from [get_ports {rst_n}]
  ```

---

### Step 3: Update Subproject Makefile

Update the `Makefile` inside `<MODULE_DIRECTORY>/` to add `pnr` and `pnr_qor` targets:

1. Update `.PHONY` line to include `pnr pnr_qor`:
   ```makefile
   .PHONY: all lint presynth_check rtl_sim syn gls_sim pnr pnr_qor clean
   ```

2. Add `pnr` target:
   ```makefile
   # PnR Flow (run_pnr.py automatically detects & uses nix develop if not active)
   pnr:
   	python3 ../tools/run_pnr.py <MODULE_NAME>
   ```

3. Add `pnr_qor` target:
   ```makefile
   # PnR QoR Report
   pnr_qor:
   	mkdir -p docs/backend
   	../tools/report_qor_phases.py ../librelane_designs/<MODULE_NAME>/runs/run_100MHz > docs/backend/pnr_qor_report.md
   ```

---

### Step 4: Update Subproject `AGENTS.md`

Add PnR reference links and execution instructions to `<MODULE_DIRECTORY>/AGENTS.md`:

```markdown
*   [config.json (PnR Config)](../librelane_designs/<MODULE_NAME>/config.json): PnR flow configuration.
*   [constraint.sdc (SDC Timing Constraints)](../librelane_designs/<MODULE_NAME>/constraint.sdc): OpenROAD STA timing constraints.
```

And in the **How to Run** section:

```bash
# Run PnR flow
make pnr

# Report PnR QoR & runtime summary
make pnr_qor
```

---

### Step 5: Verify & Report Results

1. Verify formatting of `config.json`, `constraint.sdc`, `Makefile`, and `AGENTS.md`.
2. Ensure PnR QoR metrics and signoff results are recorded in `<MODULE_DIRECTORY>/docs/backend/pnr_qor_report.md`.
3. Present a concise summary to the user including file links, applied constraints, and execution instructions.

---

## Common Mistakes to Avoid

1. **`set_dont_touch` in SDC**: Never use `set_dont_touch` in SDC files.
2. **Missing `--hide-progress-bar`**: Always include `--hide-progress-bar` in the `pnr` Makefile target.
3. **Absolute File Paths**: Never hardcode `/home/username/...` in `config.json`. Use `dir::` relative paths.
