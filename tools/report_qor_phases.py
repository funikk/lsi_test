#!/usr/bin/env python3
import os
import sys
import json
import glob

def parse_runtime(step_dir):
    if not step_dir or not os.path.exists(step_dir):
        return 0.0
    r_file = os.path.join(step_dir, "runtime.txt")
    if not os.path.exists(r_file):
        return 0.0
    try:
        with open(r_file, "r") as f:
            content = f.read().strip()
            parts = content.split(":")
            if len(parts) == 3:
                return float(parts[0]) * 3600 + float(parts[1]) * 60 + float(parts[2])
            elif len(parts) == 2:
                return float(parts[0]) * 60 + float(parts[1])
            else:
                return float(content)
    except Exception:
        return 0.0

def load_metrics_from_state(step_dir):
    if not step_dir:
        return None
    state_file = os.path.join(step_dir, "state_out.json")
    metrics = None
    if os.path.exists(state_file):
        try:
            with open(state_file, "r") as f:
                data = json.load(f)
                metrics = data.get("metrics", {})
        except Exception:
            pass
    return metrics

def extract_phase_data(metrics, corner="nom_tt_025C_1v80"):
    if not metrics:
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
        "hold_npv": hold_npv
    }

def format_hhmmss(sec):
    if sec is None:
        return "N/A"
    sec_int = int(round(sec))
    h = sec_int // 3600
    m = (sec_int % 3600) // 60
    s = sec_int % 60
    return f"{h:02d}:{m:02d}:{s:02d}"

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 report_qor_phases.py <path_to_pnr_run_dir> [corner]")
        print("Example: python3 report_qor_phases.py librelane_designs/aes_prng_top/runs/run_pnr nom_tt_025C_1v80")
        sys.exit(1)
        
    run_dir = sys.argv[1]
    corner = sys.argv[2] if len(sys.argv) > 2 else "nom_tt_025C_1v80"
    
    if not os.path.isdir(run_dir):
        print(f"Error: Directory '{run_dir}' not found.")
        sys.exit(1)
        
    # Get all numbered step directories in chronological order
    raw_step_dirs = glob.glob(os.path.join(run_dir, "[0-9]*"))
    step_dirs = []
    for d in raw_step_dirs:
        base = os.path.basename(d)
        prefix = base.split("-")[0]
        if prefix.isdigit():
            step_dirs.append((int(prefix), d))
    step_dirs.sort(key=lambda x: x[0])
    
    step_paths = [x[1] for x in step_dirs]
    step_names = [os.path.basename(p) for p in step_paths]
    runtimes = [parse_runtime(p) for p in step_paths]
    
    def find_step_index(pred, start_from=0):
        for i in range(start_from, len(step_names)):
            if pred(step_names[i]):
                return i
        return None

    # Find milestone step indices for the 4 design phases
    synth_idx = find_step_index(lambda n: "openroad-staprepnr" in n)
    if synth_idx is None:
        synth_idx = find_step_index(lambda n: "yosys-synthesis" in n)
    if synth_idx is None:
        synth_idx = 0

    place_idx = find_step_index(
        lambda n: "openroad-stamidpnr" in n and not any(n.endswith(f"-{k}") for k in range(1, 10)),
        synth_idx + 1
    )
    if place_idx is None:
        place_idx = find_step_index(lambda n: "openroad-detailedplacement" in n, synth_idx + 1)
    if place_idx is None:
        place_idx = synth_idx

    cts_idx = find_step_index(lambda n: "openroad-stamidpnr-2" in n or "openroad-stamidpnr-1" in n, place_idx + 1)
    if cts_idx is None:
        cts_idx = find_step_index(lambda n: "openroad-cts" in n, place_idx + 1)
    if cts_idx is None:
        cts_idx = place_idx

    route_idx = find_step_index(lambda n: "openroad-stapostpnr" in n, cts_idx + 1)
    if route_idx is None:
        route_idx = len(step_names) - 1

    # Load metrics from state_out.json at milestone steps
    m_synth = load_metrics_from_state(step_paths[synth_idx]) if step_paths else None
    m_place = load_metrics_from_state(step_paths[place_idx]) if step_paths else None
    m_cts = load_metrics_from_state(step_paths[cts_idx]) if step_paths else None
    m_route = load_metrics_from_state(step_paths[route_idx]) if step_paths else None
    
    synth_metrics = extract_phase_data(m_synth, corner)
    place_metrics = extract_phase_data(m_place, corner)
    cts_metrics = extract_phase_data(m_cts, corner)
    route_metrics = extract_phase_data(m_route, corner)
    
    # Calculate Phase Job Runtime Sum & Cumulative Elapsed Time
    phase_runtimes = {
        "synth": sum(runtimes[0 : synth_idx + 1]),
        "place": sum(runtimes[synth_idx + 1 : place_idx + 1]),
        "cts":   sum(runtimes[place_idx + 1 : cts_idx + 1]),
        "route": sum(runtimes[cts_idx + 1 : route_idx + 1])
    }
    
    phase_elapsed = {
        "synth": sum(runtimes[0 : synth_idx + 1]),
        "place": sum(runtimes[0 : place_idx + 1]),
        "cts":   sum(runtimes[0 : cts_idx + 1]),
        "route": sum(runtimes[0 : route_idx + 1])
    }
    
    # Total flow execution time across all steps in the run directory
    total_runtime_sec = sum(runtimes)
    total_hhmmss = format_hhmmss(total_runtime_sec)
    
    # Check final metrics.json if available
    final_json = os.path.join(run_dir, "final", "metrics.json")
    die_area, core_area = "N/A", "N/A"
    if os.path.exists(final_json):
        with open(final_json, "r") as f:
            final_data = json.load(f)
            die_area = final_data.get("design__die__area", final_data.get("die__area", "N/A"))
            core_area = final_data.get("design__core__area", final_data.get("core__area", "N/A"))
            if not route_metrics:
                route_metrics = extract_phase_data(final_data, corner)

    print("\n## PnR 各設計フェーズにおける QoR・実行時間 集計結果")
    print(f"- **ターゲット実行フォルダ**: `{run_dir}`")
    print(f"- **対象コーナー**: `{corner}`")
    print(f"- **フロー全ステップ合計実行時間**: `{total_hhmmss}` ({total_runtime_sec:.1f} 秒)")
    print(f"- **コア領域面積 (Core Area)**: `{core_area:,.2f}` µm²" if isinstance(core_area, (int, float)) else f"- **コア領域面積 (Core Area)**: `{core_area}`")
    print(f"- **ダイ全体面積 (Die Area)**: `{die_area:,.2f}` µm²\n" if isinstance(die_area, (int, float)) else f"- **ダイ全体面積 (Die Area)**: `{die_area}`\n")
    
    print("| 設計フェーズ | インスタンス数 | スタンダードセル面積 | Setup 最悪スラック | Setup NPV | Hold 最悪スラック | Hold NPV | フェーズ所要時間 (合計) | 累積経過時間 |")
    print("| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")
    
    phases = [
        ("1. 論理合成 (Synth)", synth_metrics, phase_runtimes["synth"], phase_elapsed["synth"]),
        ("2. 配置 (Place)", place_metrics, phase_runtimes["place"], phase_elapsed["place"]),
        ("3. クロックツリー (CTS)", cts_metrics, phase_runtimes["cts"], phase_elapsed["cts"]),
        ("4. 配線後 (Route)", route_metrics, phase_runtimes["route"], phase_elapsed["route"])
    ]
    
    for name, data, rt_sec, el_sec in phases:
        rt_str = format_hhmmss(rt_sec)
        el_str = format_hhmmss(el_sec)
        if data:
            inst_cnt = f"{data['instance_count']:,}"
            area_str = f"{data['area']:,.2f} µm²"
            setup_str = f"{data['setup_ws']:+.2f} ns" if data['setup_ws'] is not None else "N/A"
            setup_npv = data['setup_npv']
            hold_str = f"{data['hold_ws']:+.2f} ns" if data['hold_ws'] is not None else "N/A"
            hold_npv = data['hold_npv']
            print(f"| {name} | {inst_cnt} | {area_str} | {setup_str} | {setup_npv} | {hold_str} | {hold_npv} | {rt_str} | {el_str} |")
        else:
            print(f"| {name} | N/A | N/A | N/A | N/A | N/A | N/A | {rt_str} | {el_str} |")

    # Print Multi-Corner Timing Summary if metrics are available
    all_metrics = None
    if os.path.exists(final_json):
        try:
            with open(final_json, "r") as f:
                all_metrics = json.load(f)
        except Exception:
            pass
    if not all_metrics and m_route:
        all_metrics = m_route

    if all_metrics:
        corner_prefix = "timing__setup__ws__corner:"
        corners = []
        for key in all_metrics.keys():
            if key.startswith(corner_prefix):
                corners.append(key[len(corner_prefix):])
        corners.sort()

        if corners or "timing__setup__ws" in all_metrics:
            print("\n### 最終 Signoff Multi-Corner Timing QoR (全コーナー結果)")
            print("| コーナー / グループ | Hold WNS | Hold TNS | Hold 違反数 | Setup WNS | Setup TNS | Setup 違反数 | Max Cap 違反 | Max Slew 違反 |")
            print("| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")

            h_ws = all_metrics.get("timing__hold__ws")
            h_tns = all_metrics.get("timing__hold__tns", 0)
            h_vio = all_metrics.get("timing__hold_vio__count", 0)
            s_ws = all_metrics.get("timing__setup__ws")
            s_tns = all_metrics.get("timing__setup__tns", 0)
            s_vio = all_metrics.get("timing__setup_vio__count", 0)
            cap_vio = all_metrics.get("design__max_cap_violation__count", 0)
            slew_vio = all_metrics.get("design__max_slew_violation__count", 0)

            h_ws_str = f"{h_ws:+.4f} ns" if h_ws is not None else "N/A"
            h_tns_str = f"{h_tns:+.4f} ns" if h_tns is not None else "0.0000 ns"
            s_ws_str = f"{s_ws:+.4f} ns" if s_ws is not None else "N/A"
            s_tns_str = f"{s_tns:+.4f} ns" if s_tns is not None else "0.0000 ns"

            print(f"| **Overall** | **{h_ws_str}** | **{h_tns_str}** | **{h_vio}** | **{s_ws_str}** | **{s_tns_str}** | **{s_vio}** | **{cap_vio}** | **{slew_vio}** |")

            for c in corners:
                ch_ws = all_metrics.get(f"timing__hold__ws__corner:{c}")
                ch_tns = all_metrics.get(f"timing__hold__tns__corner:{c}", 0)
                ch_vio = all_metrics.get(f"timing__hold_vio__count__corner:{c}", 0)
                cs_ws = all_metrics.get(f"timing__setup__ws__corner:{c}")
                cs_tns = all_metrics.get(f"timing__setup__tns__corner:{c}", 0)
                cs_vio = all_metrics.get(f"timing__setup_vio__count__corner:{c}", 0)
                ccap_vio = all_metrics.get(f"design__max_cap_violation__count__corner:{c}", 0)
                cslew_vio = all_metrics.get(f"design__max_slew_violation__count__corner:{c}", 0)

                ch_ws_str = f"{ch_ws:+.4f} ns" if ch_ws is not None else "N/A"
                ch_tns_str = f"{ch_tns:+.4f} ns" if ch_tns is not None else "0.0000 ns"
                cs_ws_str = f"{cs_ws:+.4f} ns" if cs_ws is not None else "N/A"
                cs_tns_str = f"{cs_tns:+.4f} ns" if cs_tns is not None else "0.0000 ns"

                print(f"| `{c}` | {ch_ws_str} | {ch_tns_str} | {ch_vio} | {cs_ws_str} | {cs_tns_str} | {cs_vio} | {ccap_vio} | {cslew_vio} |")

if __name__ == "__main__":
    main()

