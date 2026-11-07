# ==============================================================================
# 07_cts_opt.tcl - Clock Tree Synthesis (CTS) and Clock Optimization
# ==============================================================================

echo "[FC_INFO] Starting Clock Tree Synthesis (clock_opt)..."

# Check CTS prerequisites
check_clock_trees

# Execute CTS and clock path optimization
clock_opt

# Save CTS design state
save_block -as "${DESIGN_NAME}_cts"

# CTS Timing & Clock Tree Reports
report_qor > "${REPORT_DIR}/07_cts_qor.rpt"
report_timing -delay_type min_max -max_paths 10 > "${REPORT_DIR}/07_cts_timing.rpt"
report_clock_tree_options > "${REPORT_DIR}/07_cts_tree.rpt"
report_clock_qor > "${REPORT_DIR}/07_cts_skew.rpt"

echo "[FC_INFO] Clock Tree Synthesis completed."
