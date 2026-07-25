#!/usr/bin/env python3
import os
import sys
import json

def setup_toolchain(project_dir, toolchain_name):
    valid_toolchains = ["librelane", "quartus", "commercial_asic"]
    if toolchain_name not in valid_toolchains:
        print(f"Error: Unsupported toolchain '{toolchain_name}'. Valid options: {valid_toolchains}")
        sys.exit(1)
        
    config_path = os.path.join(project_dir, "pnr", "config.json")
    if not os.path.exists(config_path):
        print(f"Error: {config_path} not found.")
        sys.exit(1)
        
    with open(config_path, "r") as f:
        config_data = json.load(f)
        
    config_data["toolchain"] = toolchain_name
    
    with open(config_path, "w") as f:
        json.dump(config_data, f, indent=4)
        
    print(f"[Methodology Engineer] Toolchain set to '{toolchain_name}' in {config_path}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 setup_toolchain.py <project_dir> <toolchain_name>")
        print("Supported toolchains: librelane, quartus, commercial_asic")
        sys.exit(1)
    setup_toolchain(sys.argv[1], sys.argv[2])
