#!/usr/bin/env python3
import os
import sys
import json
import argparse
import subprocess
import shutil
from pathlib import Path

def check_and_reexec_nix(workspace_root: Path, script_path: Path = None):
    if script_path is None:
        script_path = Path(__file__).resolve()
    try:
        import librelane  # noqa: F401
    except ImportError:
        nix_bin = shutil.which("nix")
        if nix_bin and os.environ.get("AUTO_NIX_REEXEC") != "1":
            librelane_dir = workspace_root / "librelane"
            print(f"Notice: LibreLane environment not active. Automatically entering 'nix develop {librelane_dir}'...")
            env = os.environ.copy()
            env["AUTO_NIX_REEXEC"] = "1"
            nix_cmd = [nix_bin, "develop", str(librelane_dir), "--command", "python3", str(script_path)] + sys.argv[1:]
            res = subprocess.run(nix_cmd, env=env)
            sys.exit(res.returncode)
        else:
            print("Error: 'librelane' module not found and 'nix' command is unavailable.", file=sys.stderr)
            sys.exit(1)

def resolve_paths(module_name: str):
    script_dir = Path(__file__).resolve().parent
    workspace_root = script_dir.parent
    librelane_dir = workspace_root / "librelane"
    pdk_root = workspace_root / "pdks"

    if not librelane_dir.exists():
        print(f"Error: LibreLane directory not found at {librelane_dir}", file=sys.stderr)
        sys.exit(1)

    target_design_dir = None

    # Strategy 1: Check direct subproject directory <workspace>/<module_name>/pnr/
    direct_pnr = workspace_root / module_name / "pnr"
    if (direct_pnr / "config.json").exists():
        target_design_dir = direct_pnr
    else:
        # Strategy 2: Check all project directories containing pnr/config.json
        for proj_dir in workspace_root.iterdir():
            if proj_dir.is_dir():
                pnr_dir = proj_dir / "pnr"
                cfg_file = pnr_dir / "config.json"
                if cfg_file.exists():
                    try:
                        with open(cfg_file, "r") as f:
                            cfg_data = json.load(f)
                            design_name = cfg_data.get("DESIGN_NAME", "")
                            if design_name == module_name or module_name in proj_dir.name or module_name in design_name:
                                target_design_dir = pnr_dir
                                break
                    except Exception:
                        pass

    # Strategy 3: Fallback legacy check librelane_designs/
    if not target_design_dir:
        legacy_dir = workspace_root / "librelane_designs" / module_name
        if (legacy_dir / "config.json").exists():
            target_design_dir = legacy_dir
        elif legacy_dir.parent.exists():
            matched = list(legacy_dir.parent.glob(f"*{module_name}*"))
            if matched and (matched[0] / "config.json").exists():
                target_design_dir = matched[0]

    if not target_design_dir or not (target_design_dir / "config.json").exists():
        print(f"Error: Could not resolve PnR directory for '{module_name}' under workspace.", file=sys.stderr)
        sys.exit(1)

    config_json = target_design_dir / "config.json"
    return workspace_root, librelane_dir, pdk_root, target_design_dir, config_json

def read_config_defaults(config_json: Path):
    clk_period = 10.0
    std_cell = "sky130_fd_sc_hd"
    try:
        with open(config_json, "r") as f:
            data = json.load(f)
            clk_period = float(data.get("CLOCK_PERIOD", clk_period))
            std_cell = str(data.get("STD_CELL_LIBRARY", std_cell))
    except Exception as e:
        print(f"Notice: Could not parse config.json defaults ({e}), using fallback defaults.", file=sys.stderr)
    return clk_period, std_cell

def run_single_pnr(workspace_root, librelane_dir, pdk_root, target_design_dir, config_json,
                   clk_period=None, std_cell=None, core_util=None,
                   run_tag=None, overwrite=True, from_step=None, to_step=None,
                   hide_progress_bar=True, report_qor=True, dry_run=False):

    # 1. Parse defaults from config.json if CLI arguments are not set
    default_clk_period, default_std_cell = read_config_defaults(config_json)

    eff_clk_period = clk_period if clk_period is not None else default_clk_period
    eff_std_cell = std_cell if std_cell is not None else default_std_cell
    eff_freq_mhz = int(round(1000.0 / eff_clk_period))

    # 2. Determine default or custom run_tag matching project conventions
    if not run_tag:
        if "hs" in eff_std_cell:
            run_tag = f"run_{eff_freq_mhz}MHz_hs"
        else:
            run_tag = f"run_{eff_freq_mhz}MHz"

    cmd = [
        sys.executable, "-m", "librelane"
    ]

    if hide_progress_bar:
        cmd.append("--hide-progress-bar")

    cmd.extend(["--pdk-root", str(pdk_root)])
    cmd.extend(["-p", "sky130A"])
    cmd.extend(["-s", eff_std_cell])
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
    print(f" Executing PnR Flow for {target_design_dir.name}")
    print(f" Config: {config_json.name} | Tag: {run_tag} | Target: {eff_freq_mhz}MHz ({eff_clk_period:.2f}ns) | SCL: {eff_std_cell}")
    print(f" Command: {cmd_str}")
    print(f"==========================================\n")

    if dry_run:
        print("[DRY-RUN] Command will not be executed.")
        return 0, target_design_dir / "runs" / run_tag

    res = subprocess.run(cmd, cwd=librelane_dir, env=env)
    run_dir = target_design_dir / "runs" / run_tag

    if res.returncode == 0 and report_qor:
        print("\n--- PnR Flow Complete. Outputting QoR Summary ---")
        report_script = workspace_root / "tools" / "report_qor_phases.py"
        if report_script.exists():
            subprocess.run([sys.executable, str(report_script), str(run_dir)])

    return res.returncode, run_dir

def parse_run_metrics(run_dir: Path):
    final_json = run_dir / "final" / "metrics.json"
    metrics = {
        "instances": "N/A",
        "area": "N/A",
        "setup_ws": "N/A",
        "setup_tt_ws": "N/A",
        "setup_ss_ws": "N/A",
        "setup_vio": 0,
        "hold_ws": "N/A",
        "hold_vio": 0,
        "max_cap_vio": 0,
        "max_slew_vio": 0,
        "drc": 0
    }
    if not final_json.exists():
        return metrics

    try:
        with open(final_json, "r") as f:
            data = json.load(f)
            metrics["instances"] = data.get("design__instance__count", "N/A")
            metrics["area"] = data.get("design__instance__area__stdcell", data.get("design__instance__area", "N/A"))
            metrics["setup_ws"] = data.get("timing__setup__ws", "N/A")
            metrics["setup_vio"] = data.get("timing__setup_vio__count", 0)
            metrics["hold_ws"] = data.get("timing__hold__ws", "N/A")
            metrics["hold_vio"] = data.get("timing__hold_vio__count", 0)
            metrics["drc"] = data.get("magic__drc_error__count", data.get("klayout__drc_error__count", 0))
            metrics["max_cap_vio"] = data.get("design__max_cap_violation__count", 0)
            metrics["max_slew_vio"] = data.get("design__max_slew_violation__count", 0)

            metrics["setup_tt_ws"] = data.get("timing__setup__ws__corner:nom_tt_025C_1v80", metrics["setup_ws"])
            metrics["setup_ss_ws"] = data.get("timing__setup__ws__corner:nom_ss_100C_1v60", metrics["setup_ws"])
    except Exception as e:
        print(f"Warning: Exception parsing {final_json}: {e}", file=sys.stderr)

    return metrics

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
    parser.add_argument("--report-qor", action="store_true", default=True, help="Automatically display QoR summary after run (default: True)")
    parser.add_argument("--no-report-qor", action="store_false", dest="report_qor", help="Disable automatic QoR summary display")
    parser.add_argument("--dry-run", action="store_true", help="Print generated command line without executing")

    args = parser.parse_args()

    workspace_root, librelane_dir, pdk_root, target_design_dir, config_json = resolve_paths(args.module)
    check_and_reexec_nix(workspace_root)

    if args.sweep_clk:
        periods = [float(p.strip()) for p in args.sweep_clk.split(",")]
        print(f"Starting clock period sweep over {len(periods)} values: {periods} ns")
        sweep_results = []
        for p in periods:
            freq_mhz = int(round(1000.0 / p))
            eff_scl = args.std_cell if args.std_cell else read_config_defaults(config_json)[1]
            scl_suffix = "_hs" if "hs" in eff_scl else ""
            tag = f"run_{freq_mhz}MHz{scl_suffix}"

            ret, run_dir = run_single_pnr(
                workspace_root, librelane_dir, pdk_root, target_design_dir, config_json,
                clk_period=p, std_cell=args.std_cell, core_util=args.core_util,
                run_tag=tag, overwrite=args.overwrite,
                from_step=args.from_step, to_step=args.to_step,
                report_qor=False, dry_run=args.dry_run
            )

            metrics = parse_run_metrics(run_dir) if not args.dry_run else None
            sweep_results.append({
                "period": p,
                "freq_mhz": freq_mhz,
                "tag": tag,
                "ret": ret,
                "metrics": metrics,
                "run_dir": run_dir
            })

            if ret != 0:
                print(f"Sweep stopped early due to failure at {p} ns ({freq_mhz} MHz).")
                break

        print("\n" + "=" * 80)
        print("  Clock Period Sweep QoR Comparison Summary Table")
        print("=" * 80)
        print("| Target Freq | Period (ns) | Tag Name | Status | StdCell Area | Setup WNS | Hold WNS | DRC Errors |")
        print("| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")

        for r in sweep_results:
            status_str = "SUCCESS" if r["ret"] == 0 else "FAILED"
            m = r["metrics"]
            if m and isinstance(m, dict):
                area_str = f"{m['area']:,.2f} µm²" if isinstance(m['area'], (int, float)) else str(m['area'])
                setup_str = f"{m['setup_ws']:+.2f} ns (Vio:{m['setup_vio']})" if isinstance(m['setup_ws'], (int, float)) else str(m['setup_ws'])
                hold_str = f"{m['hold_ws']:+.2f} ns (Vio:{m['hold_vio']})" if isinstance(m['hold_ws'], (int, float)) else str(m['hold_ws'])
                drc_str = str(m['drc'])
            else:
                area_str, setup_str, hold_str, drc_str = "N/A", "N/A", "N/A", "N/A"

            print(f"| {r['freq_mhz']} MHz | {r['period']:.2f} ns | `{r['tag']}` | {status_str} | {area_str} | {setup_str} | {hold_str} | {drc_str} |")
        print("=" * 80 + "\n")

        sys.exit(0 if all(r["ret"] == 0 for r in sweep_results) else 1)

    else:
        ret, _ = run_single_pnr(
            workspace_root, librelane_dir, pdk_root, target_design_dir, config_json,
            clk_period=args.clk_period, std_cell=args.std_cell, core_util=args.core_util,
            run_tag=args.run_tag, overwrite=args.overwrite,
            from_step=args.from_step, to_step=args.to_step,
            report_qor=args.report_qor, dry_run=args.dry_run
        )
        sys.exit(ret)

if __name__ == "__main__":
    main()
