#!/usr/bin/env python3
import os
import sys
import json
import argparse
from pathlib import Path

def setup_pnr(module_name: str, clock_period: float = 10.0, clock_port: str = "clk", std_cell: str = "sky130_fd_sc_hd", force: bool = False):
    root_dir = Path.cwd()
    
    # 1. Check module directory
    module_dir = root_dir / module_name
    if not module_dir.exists():
        # Fallback check for <module_name>_test
        module_dir = root_dir / f"{module_name}_test"
        if not module_dir.exists():
            print(f"Error: Module directory '{module_name}' or '{module_name}_test' not found.", file=sys.stderr)
            sys.exit(1)

    design_dir = root_dir / "librelane_designs" / module_name
    if design_dir.exists() and not force:
        print(f"Notice: Design directory '{design_dir}' already exists. Updating configuration...", file=sys.stderr)
    
    design_dir.mkdir(parents=True, exist_ok=True)

    # Find RTL files
    rtl_dir = module_dir / "rtl"
    rtl_files = []
    if rtl_dir.exists():
        rtl_files = [f for f in rtl_dir.glob("*.v")] + [f for f in rtl_dir.glob("*.sv")]
    
    rel_module_dir = module_dir.relative_to(root_dir)

    # Sort files to ensure top module or core is listed logically
    verilog_files = [f"dir::../../{rel_module_dir}/rtl/{f.name}" for f in sorted(rtl_files)]

    # 2. Create config.json
    config_data = {
        "DESIGN_NAME": module_name,
        "VERILOG_FILES": verilog_files,
        "CLOCK_PERIOD": clock_period,
        "CLOCK_PORT": clock_port,
        "CLOCK_NET": "ref::$CLOCK_PORT",
        "STD_CELL_LIBRARY": std_cell,
        "STD_CELL_LIBRARY_OPT": std_cell,
        "FP_PIN_ORDER_CFG": "dir::pin_order.cfg",
        "BASE_SDC_FILE": "dir::constraint.sdc",
        "pdk::sky130*": {
            "FP_CORE_UTIL": 40,
            "PL_TARGET_DENSITY_PCT": 45,
            "MAX_FANOUT_CONSTRAINT": 20
        }
    }

    config_path = design_dir / "config.json"
    with open(config_path, "w") as f:
        json.dump(config_data, f, indent=4)
    print(f"Created/Updated PnR config at: {config_path}")

    # 3. Create pin_order.cfg (Pin Placement Order Constraint)
    pin_cfg_content = f"""#N
{clock_port}
rst.*

#S
trap_out

#E
dmem_.*
out_.*

#W
imem_.*
in_.*
"""
    pin_cfg_path = design_dir / "pin_order.cfg"
    pin_cfg_path.write_text(pin_cfg_content)
    print(f"Created/Updated Pin Order Config at: {pin_cfg_path}")

    # 3. Create constraint.sdc (OpenROAD STA Compatible)
    sdc_content = f"""# SDC Constraints for {module_name} (Target: {1000.0/clock_period:.1f} MHz / {clock_period:.1f} ns)
# Process: SkyWater 130nm ({std_cell})

create_clock -name {clock_port} -period {clock_period:.4f} [get_ports {{{clock_port}}}]
set_clock_uncertainty 0.2500 [get_clocks {{{clock_port}}}]
set_clock_transition 0.1500 [get_clocks {{{clock_port}}}]

# Asynchronous Reset Input False Path (if rst_n exists)
set_false_path -from [get_ports {{rst_n}}] -error_quiet

# Example: Bound Inter-stage Delay Between Synchronizer DFFs (2.0 ns max)
# OpenROAD SDC Note: Do NOT use 'set_dont_touch' (invalid command in OpenSTA).
# Use wildcard pattern matching for escaped netlist cell names (*u_reset_sync*u_dff1*)
set_max_delay 2.0 -from [get_cells -hierarchical *u_reset_sync*u_dff1*] -to [get_cells -hierarchical *u_reset_sync*u_dff2*] -error_quiet
"""
    sdc_path = design_dir / "constraint.sdc"
    sdc_path.write_text(sdc_content)
    print(f"Created/Updated SDC constraints at: {sdc_path}")

    print("\nNext steps:")
    print(f"1. Check '{sdc_path}' and adjust input/output delays or module-specific constraints if needed.")
    print(f"2. Run 'make pnr' inside '{module_dir.name}/'.")

def main():
    parser = argparse.ArgumentParser(description="Automate PnR design setup for a module.")
    parser.add_argument("--name", "-n", required=True, help="Target module/subproject name (e.g. counter, fifo_top)")
    parser.add_argument("--clk-period", "-c", type=float, default=10.0, help="Clock period in ns (default: 10.0)")
    parser.add_argument("--clk-port", type=str, default="clk", help="Clock port name (default: clk)")
    parser.add_argument("--std-cell", "-s", type=str, default="sky130_fd_sc_hd", help="Standard cell library (default: sky130_fd_sc_hd)")
    parser.add_argument("--force", action="store_true", help="Force overwrite configuration files")
    args = parser.parse_args()

    setup_pnr(args.name, args.clk_period, args.clk_port, args.std_cell, args.force)

if __name__ == "__main__":
    main()
