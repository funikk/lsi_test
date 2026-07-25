# LibreLane Toolchain Reference Guide for Backend Design Engineer

## Overview
LibreLane (formerly OpenLane 2) is an open-source ASIC flow integrating Yosys (Synthesis) and OpenROAD (PnR & STA).

## Configuration (`config.json`)
```json
{
    "DESIGN_NAME": "my_top_module",
    "VERILOG_FILES": ["dir::../rtl/my_top_module.v"],
    "CLOCK_PERIOD": 10.0,
    "CLOCK_PORT": "clk",
    "CLOCK_NET": "ref::$CLOCK_PORT",
    "STD_CELL_LIBRARY": "sky130_fd_sc_hd",
    "pdk::sky130*": {
        "FP_CORE_UTIL": 40,
        "PL_TARGET_DENSITY_PCT": 45,
        "MAX_FANOUT_CONSTRAINT": 20
    }
}
```

## Primary Execution Commands
- Single Run: `python3 tools/run_pnr.py <module>`
- Clock Sweep: `python3 tools/run_pnr.py <module> --sweep-clk 10.0,8.0,6.67`
- High-Speed Library: `python3 tools/run_pnr.py <module> --std-cell sky130_fd_sc_hs`
- DoE Trial Plan: `python3 tools/run_trial_plan.py <module> --all`

## QoR & Metrics Locations
- Logs & Reports: `<module>/pnr/runs/<run_tag>/reports/`
- Final GDSII: `<module>/pnr/runs/<run_tag>/final/gds/<module>.gds`
- Phase QoR Parsing: `./tools/report_qor_phases.py <module>/pnr/runs/<run_tag>`
