# Intel / Altera Quartus FPGA Toolchain Reference Guide

## Overview
Intel Quartus Prime (Lite/Standard/Pro) is the primary FPGA implementation suite for Altera/Intel FPGAs (Cyclone, Arria, Stratix, Agilex).

## Configuration (`config.json` for Quartus)
```json
{
    "DESIGN_NAME": "my_top_module",
    "toolchain": "quartus",
    "TARGET_FAMILY": "Cyclone IV E",
    "TARGET_DEVICE": "EP4CE115F29C7",
    "CLOCK_PERIOD": 10.0,
    "CLOCK_PORT": "clk",
    "VERILOG_FILES": ["../rtl/my_top_module.v"]
}
```

## Quartus CLI Execution Workflow
Quartus Prime provides command-line executables for headless non-interactive PnR:
1. **Create Project / Assign Family**:
   `quartus_map <module> --source=../rtl/<module>.v --family="Cyclone IV E" --part=EP4CE115F29C7`
2. **Analysis & Synthesis**:
   `quartus_map <module>`
3. **Fitter (Placement & Routing)**:
   `quartus_fit <module>`
4. **TimeQuest Static Timing Analysis (STA)**:
   `quartus_sta <module>`
5. **Assembler (Bitstream / SOF Generation)**:
   `quartus_asm <module>`

## Tcl Scripting Workflow
Custom compilation and timing closure can be executed using Quartus Tcl scripts:
```bash
quartus_sh -t pnr/quartus_pnr.tcl
```
See `quartus_pnr.tcl.template` in this directory for Tcl customization.

## QoR & Metrics Extraction
- Timing Summary: `<module>.sta.rpt` (look for "Worst-case Slack", "Setup", "Hold")
- Fitter Resource Utilization: `<module>.fit.rpt` (Logic Elements, Memory Bits, DSPs)
- Bitstream Output: `<module>.sof` / `<module>.rbf`
