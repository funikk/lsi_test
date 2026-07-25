#!/usr/bin/env python3
import os
import sys
import json
import argparse
import subprocess
import shutil
from pathlib import Path

def check_and_reexec_nix(workspace_root: Path):
    try:
        import librelane  # noqa: F401
    except ImportError:
        nix_bin = shutil.which("nix")
        if nix_bin and os.environ.get("AUTO_NIX_REEXEC") != "1":
            librelane_dir = workspace_root / "librelane"
            print(f"Notice: LibreLane environment not active. Automatically entering 'nix develop {librelane_dir}'...")
            env = os.environ.copy()
            env["AUTO_NIX_REEXEC"] = "1"
            nix_cmd = [nix_bin, "develop", str(librelane_dir), "--command", "python3", str(Path(__file__).resolve())] + sys.argv[1:]
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

    designs_dir = workspace_root / "librelane_designs"
    target_design_dir = designs_dir / module_name
    if not target_design_dir.exists():
        matched = list(designs_dir.glob(f"*{module_name}*"))
        if matched:
            target_design_dir = matched[0]
        else:
            print(f"Error: Design directory for '{module_name}' not found under {designs_dir}", file=sys.stderr)
            sys.exit(1)

    trial_plan_file = target_design_dir / "trial_plan.json"
    if not trial_plan_file.exists():
        print(f"Error: trial_plan.json not found at {trial_plan_file}", file=sys.stderr)
        sys.exit(1)

    return workspace_root, librelane_dir, pdk_root, target_design_dir, trial_plan_file

def parse_metrics(run_dir: Path):
    final_json = run_dir / "final" / "metrics.json"
    metrics = {
        "instances": "N/A",
        "area": "N/A",
        "setup_tt_ws": "N/A",
        "setup_ss_ws": "N/A",
        "hold_ws": "N/A",
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
            metrics["hold_ws"] = data.get("timing__hold__ws", "N/A")
            metrics["drc"] = data.get("magic__drc_error__count", data.get("klayout__drc_error__count", 0))
            metrics["max_cap_vio"] = data.get("design__max_cap_violation__count", 0)
            metrics["max_slew_vio"] = data.get("design__max_slew_violation__count", 0)

            metrics["setup_tt_ws"] = data.get("timing__setup__ws__corner:nom_tt_025C_1v80", data.get("timing__setup__ws", "N/A"))
            metrics["setup_ss_ws"] = data.get("timing__setup__ws__corner:nom_ss_100C_1v60", data.get("timing__setup__ws", "N/A"))
    except Exception as e:
        print(f"Warning: Exception parsing {final_json}: {e}", file=sys.stderr)

    return metrics

def update_qor_report(workspace_root: Path, module_name: str, target_design_dir: Path, plan_data: dict):
    # Find module source docs directory (e.g. VDRV_v1/docs/backend/pnr_qor_report.md)
    vdrv_docs = workspace_root / "VDRV_v1" / "docs" / "backend" / "pnr_qor_report.md"
    if not vdrv_docs.parent.exists():
        vdrv_docs.parent.mkdir(parents=True, exist_ok=True)

    lines = [
        f"# {module_name} PnR & QoR Signoff Trial Report",
        "",
        "## 1. DoE Optimization Trial Matrix",
        "",
        "| Trial ID (Tag) | Description / Key Overrides | Inst Count | Area (µm²) | Max Cap Vio | Max Slew Vio | Hold WNS (ns) | Typical Setup WNS | Worst SS Setup WNS | DRC Errors | Status |",
        "| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |"
    ]

    trials = plan_data.get("trials", [])
    runs_dir = target_design_dir / "runs"

    for trial in trials:
        tag = trial.get("tag", "")
        desc = trial.get("description", "")
        run_dir = runs_dir / tag

        if run_dir.exists():
            m = parse_metrics(run_dir)
            area_str = f"{m['area']:,.2f}" if isinstance(m['area'], (int, float)) else str(m['area'])
            hold_str = f"{m['hold_ws']:+.2f}" if isinstance(m['hold_ws'], (int, float)) else str(m['hold_ws'])
            tt_str = f"{m['setup_tt_ws']:+.2f}" if isinstance(m['setup_tt_ws'], (int, float)) else str(m['setup_tt_ws'])
            ss_str = f"{m['setup_ss_ws']:+.2f}" if isinstance(m['setup_ss_ws'], (int, float)) else str(m['setup_ss_ws'])
            
            drc_val = m['drc']
            status = "PASS ✅" if drc_val == 0 and (isinstance(m['setup_ss_ws'], (int, float)) and m['setup_ss_ws'] >= 0) else ("Violating" if drc_val == 0 else "DRC Failed ❌")

            lines.append(f"| `{tag}` | {desc} | {m['instances']} | {area_str} | {m['max_cap_vio']} | {m['max_slew_vio']} | {hold_str} | {tt_str} | {ss_str} | {drc_val} | {status} |")
        else:
            lines.append(f"| `{tag}` | {desc} | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | - | Unrun |")

    lines.append("")
    lines.append("---")
    lines.append("## 2. Trial Parameter Details")
    lines.append("")
    for trial in trials:
        tag = trial.get("tag", "")
        desc = trial.get("description", "")
        overrides = json.dumps(trial.get("overrides", {}), indent=2)
        lines.append(f"### `{tag}`")
        lines.append(f"- **Description**: {desc}")
        lines.append(f"```json\n{overrides}\n```")
        lines.append("")

    vdrv_docs.write_text("\n".join(lines))
    print(f"\n[REPORT UPDATED] Written trial comparison matrix to: {vdrv_docs}")

def main():
    parser = argparse.ArgumentParser(description="DoE Trial Plan Execution & QoR Comparison Generator.")
    parser.add_argument("module", help="Target module name (e.g. VDRV_v1_core)")
    parser.add_argument("--trial", "-t", type=str, help="Specific trial tag to run (e.g. trial02_fanout15)")
    parser.add_argument("--all", action="store_true", help="Run all unrun or pending trials in sequence")
    parser.add_argument("--update-report-only", action="store_true", help="Only parse runs and update report without executing PnR")
    parser.add_argument("--dry-run", action="store_true", help="Print actions without executing LibreLane")

    args = parser.parse_args()

    workspace_root, librelane_dir, pdk_root, target_design_dir, trial_plan_file = resolve_paths(args.module)
    check_and_reexec_nix(workspace_root)

    with open(trial_plan_file, "r") as f:
        plan_data = json.load(f)

    base_config_path = target_design_dir / plan_data.get("base_config", "config.json")
    if not base_config_path.exists():
        print(f"Error: Base config not found at {base_config_path}", file=sys.stderr)
        sys.exit(1)

    with open(base_config_path, "r") as f:
        base_config_data = json.load(f)

    configs_dir = target_design_dir / "configs"
    configs_dir.mkdir(exist_ok=True)

    trials_to_run = []
    trials = plan_data.get("trials", [])

    if args.update_report_only:
        update_qor_report(workspace_root, args.module, target_design_dir, plan_data)
        sys.exit(0)

    if args.trial:
        matched = [t for t in trials if t.get("tag") == args.trial]
        if not matched:
            print(f"Error: Trial tag '{args.trial}' not found in {trial_plan_file}", file=sys.stderr)
            sys.exit(1)
        trials_to_run = matched
    elif args.all:
        trials_to_run = trials
    else:
        print("Error: Specify either --trial <tag> or --all to run trials.", file=sys.stderr)
        sys.exit(1)

    for trial in trials_to_run:
        tag = trial.get("tag")
        overrides = trial.get("overrides", {})

        # Merge base config with overrides
        merged_config = json.loads(json.dumps(base_config_data))
        for key, val in overrides.items():
            if isinstance(val, dict) and key in merged_config and isinstance(merged_config[key], dict):
                merged_config[key].update(val)
            else:
                merged_config[key] = val

        # Fix dir:: prefixes because config is moved to configs/ subdirectory
        def fix_dir_paths(obj):
            if isinstance(obj, str) and obj.startswith("dir::"):
                return "dir::../" + obj[5:]
            elif isinstance(obj, list):
                return [fix_dir_paths(item) for item in obj]
            elif isinstance(obj, dict):
                return {k: fix_dir_paths(v) for k, v in obj.items()}
            return obj
        merged_config = fix_dir_paths(merged_config)

        gen_config_file = configs_dir / f"config_{tag}.json"
        with open(gen_config_file, "w") as f:
            json.dump(merged_config, f, indent=4)

        print(f"\n=======================================================")
        print(f" Executing DoE Trial: {tag}")
        print(f" Config Generated: {gen_config_file}")
        print(f" Overrides: {overrides}")
        print(f"=======================================================")

        pnr_script = workspace_root / "tools" / "run_pnr.py"
        cmd = [
            sys.executable, str(pnr_script), args.module,
            "--run-tag", tag,
            "--overwrite"
        ]

        # Pass custom parameters directly if needed or use run_pnr.py
        env = os.environ.copy()
        
        # Invoke LibreLane directly using generated config
        librelane_cmd = [
            sys.executable, "-m", "librelane",
            "--hide-progress-bar",
            "--pdk-root", str(pdk_root),
            "-p", "sky130A",
            "-s", merged_config.get("STD_CELL_LIBRARY", "sky130_fd_sc_hs"),
            "--run-tag", tag,
            "--overwrite",
            str(gen_config_file)
        ]

        print(f"Command: {' '.join(librelane_cmd)}")
        if not args.dry_run:
            res = subprocess.run(librelane_cmd, cwd=librelane_dir, env=env)
            if res.returncode != 0:
                print(f"Trial {tag} failed with return code {res.returncode}")
        
        # Update report after trial
        update_qor_report(workspace_root, args.module, target_design_dir, plan_data)

if __name__ == "__main__":
    main()
