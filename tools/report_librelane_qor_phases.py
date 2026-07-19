#!/usr/bin/env python3
import os
import sys
import json
import glob

def find_step_dir(run_dir, pattern):
    matches = sorted(glob.glob(os.path.join(run_dir, pattern)))
    if matches:
        return matches[-1]
    return None

def load_metrics_from_state(step_dir):
    if not step_dir:
        return None, None
    state_file = os.path.join(step_dir, "state_out.json")
    runtime_file = os.path.join(step_dir, "runtime.txt")
    
    metrics = None
    if os.path.exists(state_file):
        try:
            with open(state_file, "r") as f:
                data = json.load(f)
                metrics = data.get("metrics", {})
        except Exception:
            pass
            
    runtime_sec = 0.0
    if os.path.exists(runtime_file):
        try:
            with open(runtime_file, "r") as f:
                content = f.read().strip()
                parts = content.split(":")
                if len(parts) == 3:
                    runtime_sec = float(parts[0])*3600 + float(parts[1])*60 + float(parts[2])
                elif len(parts) == 2:
                    runtime_sec = float(parts[0])*60 + float(parts[1])
                else:
                    runtime_sec = float(content)
        except Exception:
            pass

    return metrics, runtime_sec

def extract_phase_data(metrics, runtime_sec, corner="nom_tt_025C_1v80"):
    if not metrics and runtime_sec == 0.0:
        return None
    
    stdcell_area = metrics.get("design__instance__area__stdcell", metrics.get("design__instance__area", 0.0)) if metrics else 0.0
    instance_count = metrics.get("design__instance__count", 0) if metrics else 0
    
    setup_ws = metrics.get(f"timing__setup__ws__corner:{corner}", metrics.get("timing__setup__ws", None)) if metrics else None
    setup_npv = metrics.get(f"timing__setup_vio__count__corner:{corner}", metrics.get("timing__setup_vio__count", 0)) if metrics else 0
    
    hold_ws = metrics.get(f"timing__hold__ws__corner:{corner}", metrics.get("timing__hold__ws", None)) if metrics else None
    hold_npv = metrics.get(f"timing__hold_vio__count__corner:{corner}", metrics.get("timing__hold_vio__count", 0)) if metrics else 0
    
    return {
        "area": stdcell_area,
        "instance_count": instance_count,
        "setup_ws": setup_ws,
        "setup_npv": setup_npv,
        "hold_ws": hold_ws,
        "hold_npv": hold_npv,
        "runtime_sec": runtime_sec
    }

def get_total_runtime(run_dir):
    runtimes = glob.glob(os.path.join(run_dir, "*", "runtime.txt"))
    total_sec = 0.0
    for r in runtimes:
        try:
            with open(r, "r") as f:
                content = f.read().strip()
                parts = content.split(":")
                if len(parts) == 3:
                    total_sec += float(parts[0])*3600 + float(parts[1])*60 + float(parts[2])
                elif len(parts) == 2:
                    total_sec += float(parts[0])*60 + float(parts[1])
                else:
                    total_sec += float(content)
        except Exception:
            pass
    return total_sec

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 report_librelane_qor_phases.py <path_to_librelane_run_dir> [corner]")
        print("Example: python3 report_librelane_qor_phases.py librelane_designs/aes_prng_top/runs/run_librelane nom_tt_025C_1v80")
        sys.exit(1)
        
    run_dir = sys.argv[1]
    corner = sys.argv[2] if len(sys.argv) > 2 else "nom_tt_025C_1v80"
    
    if not os.path.isdir(run_dir):
        print(f"Error: Directory '{run_dir}' not found.")
        sys.exit(1)
        
    # Find key milestone step directories in LibreLane
    synth_dir = find_step_dir(run_dir, "*openroad-staprepnr") or find_step_dir(run_dir, "*yosys-synthesis")
    place_dir = find_step_dir(run_dir, "*openroad-stamidpnr") or find_step_dir(run_dir, "*openroad-detailedplacement")
    cts_dir = find_step_dir(run_dir, "*openroad-stamidpnr-2") or find_step_dir(run_dir, "*openroad-stamidpnr-1") or find_step_dir(run_dir, "*openroad-cts")
    route_dir = find_step_dir(run_dir, "*openroad-stapostpnr") or find_step_dir(run_dir, "final")
    
    # Load metrics and runtimes
    m_synth, r_synth = load_metrics_from_state(synth_dir)
    m_place, r_place = load_metrics_from_state(place_dir)
    m_cts, r_cts = load_metrics_from_state(cts_dir)
    m_route, r_route = load_metrics_from_state(route_dir)
    
    synth_metrics = extract_phase_data(m_synth, r_synth, corner)
    place_metrics = extract_phase_data(m_place, r_place, corner)
    cts_metrics = extract_phase_data(m_cts, r_cts, corner)
    route_metrics = extract_phase_data(m_route, r_route, corner)
    
    # Total runtime across all steps
    total_runtime_sec = get_total_runtime(run_dir)
    total_min = total_runtime_sec / 60.0
    
    # Check final metrics.json if available
    final_json = os.path.join(run_dir, "final", "metrics.json")
    die_area, core_area = "N/A", "N/A"
    if os.path.exists(final_json):
        with open(final_json, "r") as f:
            final_data = json.load(f)
            die_area = final_data.get("design__die__area", final_data.get("die__area", "N/A"))
            core_area = final_data.get("design__core__area", final_data.get("core__area", "N/A"))
            if not route_metrics:
                route_metrics = extract_phase_data(final_data, 0.0, corner)

    print("\n## LibreLane 各設計フェーズにおける QoR・実行時間 集計結果")
    print(f"- **ターゲット実行フォルダ**: `{run_dir}`")
    print(f"- **対象コーナー**: `{corner}`")
    print(f"- **フロー全ステップ合計実行時間**: `{total_min:.2f}` 分 ({total_runtime_sec:.1f} 秒)")
    print(f"- **コア領域面積 (Core Area)**: `{core_area:,.2f}` µm²" if isinstance(core_area, (int, float)) else f"- **コア領域面積 (Core Area)**: `{core_area}`")
    print(f"- **ダイ全体面積 (Die Area)**: `{die_area:,.2f}` µm²\n" if isinstance(die_area, (int, float)) else f"- **ダイ全体面積 (Die Area)**: `{die_area}`\n")
    
    print("| 設計フェーズ | インスタンス数 | スタンダードセル面積 | Setup 最悪スラック | Setup NPV | Hold 最悪スラック | Hold NPV | ステップ所要時間 |")
    print("| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")
    
    phases = [
        ("1. 論理合成 (Synth)", synth_metrics),
        ("2. 配置 (Place)", place_metrics),
        ("3. クロックツリー (CTS)", cts_metrics),
        ("4. 配線後 (Route)", route_metrics)
    ]
    
    for name, data in phases:
        if data:
            inst_cnt = f"{data['instance_count']:,}"
            area_str = f"{data['area']:,.2f} µm²"
            setup_str = f"{data['setup_ws']:+.2f} ns" if data['setup_ws'] is not None else "N/A"
            setup_npv = data['setup_npv']
            hold_str = f"{data['hold_ws']:+.2f} ns" if data['hold_ws'] is not None else "N/A"
            hold_npv = data['hold_npv']
            r_str = f"{data['runtime_sec']:.1f} 秒"
            print(f"| {name} | {inst_cnt} | {area_str} | {setup_str} | {setup_npv} | {hold_str} | {hold_npv} | {r_str} |")
        else:
            print(f"| {name} | N/A | N/A | N/A | N/A | N/A | N/A | N/A |")

if __name__ == "__main__":
    main()
