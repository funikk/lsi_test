#!/usr/bin/env python3
import os
import sys
import json
import argparse
import subprocess
from pathlib import Path

# Import shared PnR helper functions from run_pnr.py
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_pnr import check_librelane_env, resolve_paths, run_single_pnr, parse_run_metrics

def resolve_trial_plan_paths(module_name: str):
    workspace_root, librelane_dir, pdk_root, target_design_dir, config_json = resolve_paths(module_name)
    trial_plan_file = target_design_dir / "trial_plan.json"
    if not trial_plan_file.exists():
        print(f"Error: trial_plan.json not found at {trial_plan_file}", file=sys.stderr)
        sys.exit(1)
    return workspace_root, librelane_dir, pdk_root, target_design_dir, trial_plan_file

def update_qor_report(workspace_root: Path, module_name: str, target_design_dir: Path, plan_data: dict):
    proj_dir = target_design_dir.parent if target_design_dir.name == "pnr" else target_design_dir
    report_file = proj_dir / "docs" / "backend" / "pnr_qor_report.md"
    if not report_file.parent.exists():
        report_file.parent.mkdir(parents=True, exist_ok=True)

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
            m = parse_run_metrics(run_dir)
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

    report_file.write_text("\n".join(lines))
    print(f"\n[REPORT UPDATED] Written trial comparison matrix to: {report_file}")

def main():
    parser = argparse.ArgumentParser(description="DoE Trial Plan Execution & QoR Comparison Generator.")
    parser.add_argument("module", help="Target module name (e.g. VDRV_v1_core)")
    parser.add_argument("--trial", "-t", type=str, help="Specific trial tag to run (e.g. trial02_fanout15)")
    parser.add_argument("--all", action="store_true", help="Run all unrun or pending trials in sequence")
    parser.add_argument("--update-report-only", action="store_true", help="Only parse runs and update report without executing PnR")
    parser.add_argument("--dry-run", action="store_true", help="Print actions without executing LibreLane")

    args = parser.parse_args()

    workspace_root, librelane_dir, pdk_root, target_design_dir, trial_plan_file = resolve_trial_plan_paths(args.module)
    check_librelane_env()

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
        print(f" Config Generated: {gen_config_file.name}")
        print(f" Overrides: {overrides}")
        print(f"=======================================================")

        # Run PnR using shared run_single_pnr helper
        ret, _ = run_single_pnr(
            workspace_root, librelane_dir, pdk_root, target_design_dir, gen_config_file,
            run_tag=tag, overwrite=True, report_qor=True, dry_run=args.dry_run
        )

        if ret != 0:
            print(f"Trial {tag} failed with return code {ret}")

        # Update report after trial
        update_qor_report(workspace_root, args.module, target_design_dir, plan_data)

if __name__ == "__main__":
    main()
