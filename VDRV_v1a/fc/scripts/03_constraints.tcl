# ==============================================================================
# 03_constraints.tcl - Load SDC Timing & Operating Constraints
# ==============================================================================

echo "[FC_INFO] Applying SDC constraints..."

set sdc_file "${INPUT_DIR}/constraint.sdc"

if {[file exists $sdc_file]} {
    read_sdc $sdc_file
    echo "[FC_INFO] Successfully loaded SDC: $sdc_file"
} else {
    echo "[FC_ERROR] SDC file not found: $sdc_file"
    return -code error
}

# Propagate clocks and check timing constraints
check_timing
report_clocks
report_ports -verbose > "${REPORT_DIR}/initial_ports.rpt"

echo "[FC_INFO] Timing constraint validation completed."
