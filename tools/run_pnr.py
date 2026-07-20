#!/usr/bin/env python3
import os
import sys
import argparse
import subprocess
from pathlib import Path

def resolve_paths(module_name: str):
    script_dir = Path(__file__).resolve().parent
    workspace_root = script_dir.parent
    librelane_dir = workspace_root / "librelane"
    pdk_root = workspace_root / "pdks"

    if not librelane_dir.exists():
        print(f"Error: LibreLane directory not found at {librelane_dir}", file=sys.stderr)
        sys.exit(1)

    # Resolve config file under librelane_designs/
    designs_dir = workspace_root / "librelane_designs"
    target_design_dir = designs_dir / module_name
    
    if not target_design_dir.exists():
        # Fallback check if full name ends with _test or _core
        matched = list(designs_dir.glob(f"*{module_name}*"))
        if matched:
            target_design_dir = matched[0]
        else:
            print(f"Error: Design directory for '{module_name}' not found under {designs_dir}", file=sys.stderr)
            sys.exit(1)

    config_json = target_design_dir / "config.json"
    if not config_json.exists():
        print(f"Error: config.json not found at {config_json}", file=sys.stderr)
        sys.exit(1)

    return workspace_root, librelane_dir, pdk_root, config_json

def run_single_pnr(workspace_root, librelane_dir, pdk_root, config_json,
                   clk_period=None, std_cell=None, core_util=None,
                   run_tag=None, overwrite=True, from_step=None, to_step=None,
                   hide_progress_bar=True, dry_run=False):

    cmd = [
        "uv", "run", "--python", "3.12", "python3", "-m", "librelane"
    ]

    if hide_progress_bar:
        cmd.append("--hide-progress-bar")

    cmd.extend(["--pdk-root", str(pdk_root)])
    cmd.extend(["-p", "sky130A"])

    if std_cell:
        cmd.extend(["-s", std_cell])
    else:
        cmd.extend(["-s", "sky130_fd_sc_hd"])

    # Determine default or custom run_tag
    if not run_tag:
        tag_parts = ["run"]
        if clk_period is not None:
            freq_mhz = int(round(1000.0 / clk_period))
            tag_parts.append(f"{freq_mhz}MHz")
        else:
            tag_parts.append("pnr")
        
        if std_cell:
            short_scl = "hs" if "hs" in std_cell else "hd"
            tag_parts.append(short_scl)
        
        run_tag = "_".join(tag_parts)

    cmd.extend(["--run-tag", run_tag])

    if overwrite:
        cmd.append("--overwrite")

    if from_step:
        cmd.extend(["--from", from_step])

    if to_step:
        cmd.extend(["--to", to_step])

    # Dynamic config overrides
    if clk_period is not None:
        cmd.extend(["-c", f"CLOCK_PERIOD={clk_period:.4f}"])

    if core_util is not None:
        cmd.extend(["-c", f"pdk::sky130*.FP_CORE_UTIL={core_util}"])

    cmd.append(str(config_json))

    # Prepare environment
    env = os.environ.copy()
    env["PDK_ROOT"] = str(pdk_root)

    cmd_str = " ".join(cmd)
    print(f"\n==========================================")
    print(f" Executing PnR Flow for {config_json.parent.name}")
    print(f" Command: {cmd_str}")
    print(f"==========================================\n")

    if dry_run:
        print("[DRY-RUN] Command will not be executed.")
        return 0

    res = subprocess.run(cmd, cwd=librelane_dir, env=env)
    return res.returncode

def main():
    parser = argparse.ArgumentParser(description="Unified PnR execution & sweep script for LibreLane flow.")
    parser.add_argument("module", help="Target module/design name (e.g. counter, mac_array, cpu_aes_prng_core)")
    parser.add_argument("--clk-period", "-c", type=float, help="Clock period in ns (e.g. 10.0 = 100MHz)")
    parser.add_argument("--std-cell", "-s", type=str, help="Standard cell library (e.g. sky130_fd_sc_hd, sky130_fd_sc_hs)")
    parser.add_argument("--core-util", "-u", type=float, help="Core area utilization percentage (e.g. 40)")
    parser.add_argument("--run-tag", "-t", type=str, help="Custom run tag name (default: auto-generated from parameters)")
    parser.add_argument("--overwrite", action="store_true", default=True, help="Overwrite existing run directory (default: True)")
    parser.add_argument("--no-overwrite", action="store_false", dest="overwrite", help="Do not overwrite existing run directory")
    parser.add_argument("--from-step", type=str, help="Resume flow starting from step ID (e.g. openroad-detailedplacement)")
    parser.add_argument("--to-step", type=str, help="Stop flow at step ID")
    parser.add_argument("--sweep-clk", type=str, help="Comma-separated list of clock periods in ns for sweep testing (e.g. 10.0,8.0,6.67,5.0)")
    parser.add_argument("--dry-run", action="store_true", help="Print generated command line without executing")

    args = parser.parse_args()

    workspace_root, librelane_dir, pdk_root, config_json = resolve_paths(args.module)

    if args.sweep_clk:
        periods = [float(p.strip()) for p in args.sweep_clk.split(",")]
        print(f"Starting clock period sweep over {len(periods)} values: {periods}")
        results = {}
        for p in periods:
            tag = f"run_{int(round(1000.0/p))}MHz"
            ret = run_single_pnr(
                workspace_root, librelane_dir, pdk_root, config_json,
                clk_period=p, std_cell=args.std_cell, core_util=args.core_util,
                run_tag=tag, overwrite=args.overwrite,
                from_step=args.from_step, to_step=args.to_step, dry_run=args.dry_run
            )
            results[p] = ret
            if ret != 0:
                print(f"Sweep stopped early due to failure at {p} ns ({1000.0/p:.1f} MHz).")
                break
        
        print("\n--- Sweep Summary ---")
        for p, ret in results.items():
            status = "SUCCESS" if ret == 0 else "FAILED"
            print(f"  {p:.2f} ns ({1000.0/p:.1f} MHz): {status}")
        
        sys.exit(0 if all(r == 0 for r in results.values()) else 1)
    else:
        ret = run_single_pnr(
            workspace_root, librelane_dir, pdk_root, config_json,
            clk_period=args.clk_period, std_cell=args.std_cell, core_util=args.core_util,
            run_tag=args.run_tag, overwrite=args.overwrite,
            from_step=args.from_step, to_step=args.to_step, dry_run=args.dry_run
        )
        sys.exit(ret)

if __name__ == "__main__":
    main()
