---
name: librelane-setup
description: >-
  Use when the user asks to set up, configure, or prepare the LibreLane (OpenLane 2) PnR execution environment for a Verilog/SystemVerilog RTL module, or when integrating a new module into physical design. Generates librelane_designs/<module>/config.json, updates subproject Makefile with librelane (including --hide-progress-bar) and librelane_qor targets, updates AGENTS.md, and verifies RTL quality with pre-synthesis checks.
---

# LibreLane Design Setup Skill

## Overview

This skill automates the setup of the **LibreLane** (OpenLane 2) Physical Design (PnR) execution environment for any Verilog / SystemVerilog subproject within the `lsi_test` workspace.

When requested to create or configure a LibreLane environment for a module, follow this protocol.

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
> If any optional parameter is omitted by the user, apply the default value specified above and explicitly list the applied defaults in the final summary report.

---

## Step-by-Step Execution Workflow

### Step 1: RTL Inspection & Pre-Synthesis Quality Check

1. Inspect top-level RTL file in `<MODULE_NAME>_test/rtl/` or `<MODULE_NAME>/rtl/` to confirm:
   - Top-level module name (`DESIGN_NAME`)
   - Clock port name (`CLOCK_PORT`)
   - All Verilog source files required for synthesis
2. Run pre-synthesis quality check:
   ```bash
   cd <MODULE_DIRECTORY> && make presynth_check
   ```
3. **Error Handling**:
   - If minor discrepancies (e.g., clock port named `clock` or `clk_i` instead of `clk`) are found, auto-adjust `CLOCK_PORT` accordingly.
   - If critical synthesis errors (e.g. multiple drivers, unmapped latches) occur, report the error details to the user and suggest fixes before proceeding.

---

### Step 2: Create `config.json` Configuration File

Create the configuration file at `librelane_designs/<MODULE_NAME>/config.json`.

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
    "pdk::sky130*": {
        "FP_CORE_UTIL": 40,
        "PL_TARGET_DENSITY_PCT": 45,
        "MAX_FANOUT_CONSTRAINT": 20
    }
}
```

> [!IMPORTANT]
> Always use `dir::` relative paths in `VERILOG_FILES` to maintain project portability. Never use absolute paths (`/home/...`).

---

### Step 3: Update Subproject Makefile

Update the `Makefile` inside `<MODULE_DIRECTORY>/` to add `librelane` and `librelane_qor` targets:

1. Update `.PHONY` line to include `librelane librelane_qor`:
   ```makefile
   .PHONY: all lint presynth_check rtl_sim syn gls_sim librelane librelane_qor clean
   ```

2. Add `librelane` target with `--hide-progress-bar`:
   ```makefile
   # LibreLane PnR Flow
   librelane:
   	cd ../librelane && export PDK_ROOT=$$(pwd)/../pdks && export UV_PYTHON_INSTALL_DIR=$$(pwd)/.uv_python && export UV_CACHE_DIR=$$(pwd)/.uv_cache && uv run --python 3.12 python3 -m librelane -m $$(pwd)/.. --dockerized \
   		--hide-progress-bar \
   		--pdk-root $$(pwd)/../pdks \
   		-p sky130A \
   		-s sky130_fd_sc_hd \
   		--run-tag run_100MHz \
   		../librelane_designs/<MODULE_NAME>/config.json
   ```

3. Add `librelane_qor` target:
   ```makefile
   # LibreLane QoR Report
   librelane_qor:
   	../tools/report_librelane_qor_phases.py ../librelane_designs/<MODULE_NAME>/runs/run_100MHz
   ```

---

### Step 4: Update Subproject `AGENTS.md`

Add LibreLane reference links and execution instructions to `<MODULE_DIRECTORY>/AGENTS.md`:

```markdown
*   [config.json (LibreLane Config)](../librelane_designs/<MODULE_NAME>/config.json): LibreLane PnR flow configuration.
```

And in the **How to Run** section:

```bash
# Run LibreLane PnR flow
make librelane

# Report LibreLane QoR & runtime summary
make librelane_qor
```

---

### Step 5: Verify & Report Results

1. Verify that `librelane_designs/<MODULE_NAME>/config.json`, `Makefile`, and `AGENTS.md` are correctly formatted.
2. Present a concise summary to the user including:
   - Paths to created/modified files (using `file://` markdown links).
   - Applied constraints and default values (e.g. `CLOCK_PERIOD`, `CLOCK_PORT`, `STD_CELL_LIBRARY`).
   - Instructions on how to run `make librelane` and `make librelane_qor`.

---

## Common Mistakes to Avoid

1. **Missing `--hide-progress-bar`**: Always include `--hide-progress-bar` in the `librelane` Makefile target to avoid bloated terminal logs.
2. **Absolute File Paths**: Never hardcode `/home/username/...` in `config.json`. Use `dir::` relative paths.
3. **Incorrect Tab Indentation**: Ensure Makefile recipe lines use tab characters (`\t`), not spaces.
