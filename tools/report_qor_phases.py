#!/usr/bin/env python3
import os
import sys
import re
import csv

def parse_summary_rpt(file_path):
    if not os.path.exists(file_path):
        return None
    with open(file_path, 'r') as f:
        content = f.read()
    
    tns = 0.0
    wns = 0.0
    setup = 0.0
    hold = 0.0
    
    tns_match = re.search(r'tns\s+(-?[\d\.]+)', content)
    wns_match = re.search(r'wns\s+(-?[\d\.]+)', content)
    setup_match = re.search(r'report_worst_slack\s+-max\s+\(Setup\)\s*\n=+\s*\nworst\s+slack\s+(-?[\d\.]+)', content)
    hold_match = re.search(r'report_worst_slack\s+-min\s+\(Hold\)\s*\n=+\s*\nworst\s+slack\s+(-?[\d\.]+)', content)
    
    if tns_match: tns = float(tns_match.group(1))
    if wns_match: wns = float(wns_match.group(1))
    if setup_match: setup = float(setup_match.group(1))
    if hold_match: hold = float(hold_match.group(1))
    
    return {'tns': tns, 'wns': wns, 'setup': setup, 'hold': hold}

def count_violations_split(checks_file_path):
    setup_violations = 0
    hold_violations = 0
    if not os.path.exists(checks_file_path):
        return 0, 0
    
    current_path_type = None
    with open(checks_file_path, 'r') as f:
        for line in f:
            path_type_match = re.search(r'Path Type:\s+(max|min)', line)
            if path_type_match:
                current_path_type = path_type_match.group(1)
            if 'slack (VIOLATED)' in line:
                if current_path_type == 'max':
                    setup_violations += 1
                elif current_path_type == 'min':
                    hold_violations += 1
    return setup_violations, hold_violations

def parse_synth_area(file_path):
    if not os.path.exists(file_path):
        return 0.0
    with open(file_path, 'r') as f:
        content = f.read()
    match = re.search(r'Chip area for module.+:\s*([\d\.]+)', content)
    if match:
        return float(match.group(1))
    return 0.0

def parse_log_area(file_path):
    if not os.path.exists(file_path):
        return (0.0, 0.0)
    with open(file_path, 'r') as f:
        content = f.read()
    match = re.search(r'Design area\s*([\d\.]+)\s*u\^2\s*(\d+)%\s*utilization', content)
    if match:
        return (float(match.group(1)), float(match.group(2)))
    return (0.0, 0.0)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 report_qor_phases.py <path_to_run_directory>")
        sys.exit(1)
        
    run_dir = sys.argv[1]
    if not os.path.isdir(run_dir):
        print(f"Error: Directory '{run_dir}' not found.")
        sys.exit(1)
        
    # Paths to files
    synth_area_file = os.path.join(run_dir, "reports/synthesis/1-synthesis.AREA_0.stat.rpt")
    synth_sta_file = os.path.join(run_dir, "reports/synthesis/2-syn_sta.summary.rpt")
    synth_checks_file = os.path.join(run_dir, "reports/synthesis/2-syn_sta.checks.rpt")
    
    place_log_file = os.path.join(run_dir, "logs/placement/9-resizer.log")
    place_sta_file = os.path.join(run_dir, "reports/placement/11-dpl_sta.summary.rpt")
    place_checks_file = os.path.join(run_dir, "reports/placement/11-dpl_sta.checks.rpt")
    
    cts_log_file = os.path.join(run_dir, "logs/cts/14-resizer.log")
    cts_sta_file = os.path.join(run_dir, "reports/routing/16-rsz_design_sta.summary.rpt")
    cts_checks_file = os.path.join(run_dir, "reports/routing/16-rsz_design_sta.checks.rpt")
    
    route_log_file = os.path.join(run_dir, "logs/routing/17-resizer_timing.log")
    route_sta_file = os.path.join(run_dir, "reports/signoff/31-rcx_sta.summary.rpt")
    route_checks_file = os.path.join(run_dir, "reports/signoff/31-rcx_sta.checks.rpt")
    
    metrics_file = os.path.join(run_dir, "reports/metrics.csv")
    
    # Parsing values
    # 1. Synthesis
    synth_area = parse_synth_area(synth_area_file)
    synth_timing = parse_summary_rpt(synth_sta_file)
    synth_setup_npv, synth_hold_npv = count_violations_split(synth_checks_file)
    
    # 2. Placement
    place_area, place_util = parse_log_area(place_log_file)
    place_timing = parse_summary_rpt(place_sta_file)
    place_setup_npv, place_hold_npv = count_violations_split(place_checks_file)
    
    # 3. CTS
    cts_area, cts_util = parse_log_area(cts_log_file)
    cts_timing = parse_summary_rpt(cts_sta_file)
    cts_setup_npv, cts_hold_npv = count_violations_split(cts_checks_file)
    
    # 4. Routing
    route_area, route_util = parse_log_area(route_log_file)
    route_timing = parse_summary_rpt(route_sta_file)
    route_setup_npv, route_hold_npv = count_violations_split(route_checks_file)
    
    # Die / Core Area
    die_area = "N/A"
    core_area = "N/A"
    if os.path.exists(metrics_file):
        with open(metrics_file, 'r') as f:
            reader = csv.reader(f)
            headers = next(reader)
            values = next(reader)
            metrics = dict(zip(headers, values))
            die_area = metrics.get("DIEAREA_mm^2", "N/A")
            core_area = metrics.get("CoreArea_um^2", "N/A")
            
    # Output markdown table
    print("\n## 各設計フェーズにおける QoR 集計結果")
    print(f"- **ターゲット実行フォルダ**: `{run_dir}`")
    print(f"- **コア領域面積 (Core Area)**: `{core_area}` um²")
    print(f"- **ダイ全体面積 (Die Area)**: `{die_area}` mm²\n")
    print("| 設計フェーズ | スタンダードセル面積 (利用率) | Setup 最悪スラック | Setup NPV | Hold 最悪スラック | Hold NPV |")
    print("| :--- | :---: | :---: | :---: | :---: | :---: |")
    
    # Synthesis row
    if synth_timing:
        print(f"| 1. 論理合成 (Synth) | {synth_area:,.2f} µm² (N/A) | {synth_timing['setup']:+.2f} ns | {synth_setup_npv} | {synth_timing['hold']:+.2f} ns | {synth_hold_npv} |")
    else:
        print("| 1. 論理合成 (Synth) | N/A | N/A | N/A | N/A | N/A |")
        
    # Placement row
    if place_timing:
        print(f"| 2. 配置 (Place) | {place_area:,.2f} µm² ({place_util}%) | {place_timing['setup']:+.2f} ns | {place_setup_npv} | {place_timing['hold']:+.2f} ns | {place_hold_npv} |")
    else:
        print("| 2. 配置 (Place) | N/A | N/A | N/A | N/A | N/A |")
        
    # CTS row
    if cts_timing:
        print(f"| 3. クロックツリー (CTS) | {cts_area:,.2f} µm² ({cts_util}%) | {cts_timing['setup']:+.2f} ns | {cts_setup_npv} | {cts_timing['hold']:+.2f} ns | {cts_hold_npv} |")
    else:
        print("| 3. クロックツリー (CTS) | N/A | N/A | N/A | N/A | N/A |")
        
    # Routing row
    if route_timing:
        print(f"| 4. 配線後 (Route) | {route_area:,.2f} µm² ({route_util}%) | {route_timing['setup']:+.2f} ns | {route_setup_npv} | {route_timing['hold']:+.2f} ns | {route_hold_npv} |")
    else:
        print("| 4. 配線後 (Route) | N/A | N/A | N/A | N/A | N/A |")

if __name__ == "__main__":
    main()
