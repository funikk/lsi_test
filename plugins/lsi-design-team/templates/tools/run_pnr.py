#!/usr/bin/env python3
import os
import sys
import json
import argparse
import subprocess

def run_librelane(project_dir, module_name, config_path, args):
    print(f"[Unified PnR CLI] Launching LibreLane Open-Source ASIC flow for '{module_name}'...")
    # Calls LibreLane runner or system librelane
    cmd = ["librelane", "--config", config_path]
    if args.tag:
        cmd.extend(["--run-tag", args.tag])
    print(f"Executing: {' '.join(cmd)}")
    # Simulated execution wrapper (or subprocess execution)
    return subprocess.call(cmd)

def run_quartus(project_dir, module_name, config_path, args):
    print(f"[Unified PnR CLI] Launching Intel Quartus Prime FPGA flow for '{module_name}'...")
    with open(config_path, "r") as f:
        config = json.load(f)
    family = config.get("TARGET_FAMILY", "Cyclone IV E")
    device = config.get("TARGET_DEVICE", "EP4CE115F29C7")
    
    # Run Quartus CLI commands or Tcl
    print(f"Target Family: {family}, Device: {device}")
    map_cmd = ["quartus_map", module_name, f"--family={family}", f"--part={device}"]
    fit_cmd = ["quartus_fit", module_name]
    sta_cmd = ["quartus_sta", module_name]
    asm_cmd = ["quartus_asm", module_name]
    
    print(f"Step 1 (Map): {' '.join(map_cmd)}")
    print(f"Step 2 (Fit): {' '.join(fit_cmd)}")
    print(f"Step 3 (STA): {' '.join(sta_cmd)}")
    print(f"Step 4 (Asm): {' '.join(asm_cmd)}")
    return 0

def main():
    parser = argparse.ArgumentParser(description="Unified PnR Execution Engine (LibreLane / Intel Quartus)")
    parser.add_argument("module", help="Name of the module / project directory")
    parser.add_argument("--tag", help="Run tag for output results")
    parser.add_argument("--toolchain", help="Override toolchain (librelane | quartus | commercial_asic)")
    args = parser.parse_args()

    project_dir = os.path.abspath(args.module)
    config_path = os.path.join(project_dir, "pnr", "config.json")

    if not os.path.exists(config_path):
        print(f"Error: Configuration file not found at {config_path}")
        sys.exit(1)

    with open(config_path, "r") as f:
        config = json.load(f)

    toolchain = args.toolchain or config.get("toolchain", "librelane")
    print(f"[Unified PnR CLI] Target Module: {args.module} | Toolchain: {toolchain}")

    if toolchain == "librelane":
        sys.exit(run_librelane(project_dir, args.module, config_path, args))
    elif toolchain == "quartus":
        sys.exit(run_quartus(project_dir, args.module, config_path, args))
    else:
        print(f"Error: Toolchain '{toolchain}' is not supported yet.")
        sys.exit(1)

if __name__ == "__main__":
    main()
