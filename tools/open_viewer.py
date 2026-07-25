#!/usr/bin/env python3
import os
import sys
import json
import argparse
import subprocess
import shutil
from pathlib import Path

VALID_VIEWERS = {
    "openroad": "openinopenroad",
    "openinopenroad": "openinopenroad",
    "klayout": "openinklayout",
    "openinklayout": "openinklayout",
    "magic": "openinmagic",
    "openinmagic": "openinmagic"
}

def check_librelane_env():
    try:
        import librelane  # noqa: F401
    except ImportError:
        print("Error: 'librelane' module not found.", file=sys.stderr)
        print("Please run this script inside Nix shell environment using:", file=sys.stderr)
        print("  nix develop ./librelane --command python3 tools/open_viewer.py <viewer> <module>", file=sys.stderr)
        print("or use ./tools/open_viewer.sh script.", file=sys.stderr)
        sys.exit(1)

def resolve_design_dir(workspace_root: Path, target_input: str) -> Path:
    target_path = Path(target_input)
    if target_path.exists():
        if target_path.is_file():
            return target_path.parent.parent if target_path.parent.name == "configs" else target_path.parent
        elif target_path.is_dir():
            return target_path / "pnr" if (target_path / "pnr" / "config.json").exists() else target_path

    # Strategy 1: Check direct subproject directory <workspace>/<target_input>/pnr/
    direct_pnr = workspace_root / target_input / "pnr"
    if (direct_pnr / "config.json").exists():
        return direct_pnr

    # Strategy 2: Check all subproject directories for pnr/config.json matching target_input
    for proj_dir in workspace_root.iterdir():
        if proj_dir.is_dir():
            pnr_dir = proj_dir / "pnr"
            cfg_file = pnr_dir / "config.json"
            if cfg_file.exists():
                try:
                    with open(cfg_file, "r") as f:
                        cfg_data = json.load(f)
                        design_name = cfg_data.get("DESIGN_NAME", "")
                        if design_name == target_input or target_input in proj_dir.name or target_input in design_name:
                            return pnr_dir
                except Exception:
                    pass

    # Strategy 3: Legacy librelane_designs check
    designs_dir = workspace_root / "librelane_designs"
    if (designs_dir / target_input / "config.json").exists():
        return designs_dir / target_input
    elif designs_dir.exists():
        matched = list(designs_dir.glob(f"*{target_input}*"))
        if matched and (matched[0] / "config.json").exists():
            return matched[0]

    print(f"Error: Design directory for '{target_input}' not found under workspace", file=sys.stderr)
    sys.exit(1)

def find_latest_run_tag(target_design_dir: Path) -> str:
    runs_dir = target_design_dir / "runs"
    if runs_dir.exists():
        run_dirs = [d for d in runs_dir.iterdir() if d.is_dir()]
        if run_dirs:
            run_dirs.sort(key=lambda d: d.stat().st_mtime, reverse=True)
            return run_dirs[0].name
    return "run_100MHz"

def resolve_config_for_tag(target_design_dir: Path, run_tag: str, target_input: str) -> Path:
    # If target_input is a direct file path to a json file
    input_path = Path(target_input)
    if input_path.exists() and input_path.is_file() and input_path.name.endswith(".json"):
        return input_path

    # Primary choice: Use root config.json to anchor runs/ at design root
    default_config = target_design_dir / "config.json"
    if default_config.exists():
        return default_config

    trial_config = target_design_dir / "configs" / f"config_{run_tag}.json"
    if trial_config.exists():
        return trial_config

    jsons = list(target_design_dir.glob("*.json"))
    if jsons:
        return jsons[0]

    print(f"Error: No config json file found under {target_design_dir}", file=sys.stderr)
    sys.exit(1)

def read_scl(config_json: Path) -> str:
    std_cell = "sky130_fd_sc_hd"
    try:
        with open(config_json, "r") as f:
            data = json.load(f)
            std_cell = str(data.get("STD_CELL_LIBRARY", std_cell))
    except Exception:
        pass
    return std_cell

def main():
    if "-h" in sys.argv or "--help" in sys.argv:
        print("""Usage: python3 tools/open_viewer.py [viewer] [module] [run_tag]

Purpose:
  Launching GUI Viewers for LibreLane PnR layouts & masks.

Supported Viewers:
  openroad, klayout, magic

Argument Order Flexibility:
  Positional arguments can be provided flexibly. The script auto-detects the viewer name
  and uses the remaining arguments for the module and run tag.

Examples:
  python3 tools/open_viewer.py openroad counter
  python3 tools/open_viewer.py klayout aes run_50MHz
  python3 tools/open_viewer.py picorv32 magic""")
        sys.exit(0)

    script_dir = Path(__file__).resolve().parent
    workspace_root = script_dir.parent
    librelane_dir = workspace_root / "librelane"
    pdk_root = workspace_root / "pdks"

    check_librelane_env()

    # Positional args processing
    args_list = sys.argv[1:]
    
    viewer_name = None
    target_input = None
    custom_tag = None

    # Parse positional parameters flexibly
    remaining = []
    for arg in args_list:
        if arg.startswith("-"):
            remaining.append(arg)
            continue
        lower_arg = arg.lower()
        if lower_arg in VALID_VIEWERS and viewer_name is None:
            viewer_name = lower_arg
        elif target_input is None:
            target_input = arg
        elif custom_tag is None:
            custom_tag = arg
        else:
            remaining.append(arg)

    # Defaults
    if viewer_name is None:
        viewer_name = "openroad"
    if target_input is None:
        target_input = "counter"

    flow = VALID_VIEWERS[viewer_name]
    target_design_dir = resolve_design_dir(workspace_root, target_input)
    run_tag = custom_tag if custom_tag else find_latest_run_tag(target_design_dir)
    config_json = resolve_config_for_tag(target_design_dir, run_tag, target_input)
    std_cell = read_scl(config_json)

    # Ensure DISPLAY variable for GUI
    if "DISPLAY" not in os.environ or not os.environ["DISPLAY"]:
        os.environ["DISPLAY"] = ":0"

    print(f"==========================================")
    print(f" Launching GUI Viewer for Design: {target_design_dir.name}")
    print(f" Viewer: {viewer_name} ({flow}) | Run Tag: {run_tag} | SCL: {std_cell}")
    print(f" Config Anchor: {config_json}")
    print(f" Target Runs Dir: {target_design_dir / 'runs' / run_tag}")
    print(f"==========================================\n")

    cmd = [
        sys.executable, "-m", "librelane",
        "--pdk-root", str(pdk_root),
        "-p", "sky130A",
        "-s", std_cell,
        "--run-tag", run_tag,
        "-f", flow,
        str(config_json)
    ]

    env = os.environ.copy()
    env["PDK_ROOT"] = str(pdk_root)

    res = subprocess.run(cmd, cwd=librelane_dir, env=env)
    sys.exit(res.returncode)

if __name__ == "__main__":
    main()
