# ==============================================================================
# 06_place_opt.tcl - Standard Cell Placement and Pre-CTS Optimization
# ==============================================================================

echo "[FC_INFO] Starting standard cell placement and optimization (place_opt)..."

# Target placement density ~ 45%
set_app_options -name opt.common.max_fanout -value 20
set_app_options -name place.coarse.congestion_analysis_effort -value "high"

# Execute Placement and Optimization
place_opt

# Legalize and verify placement
check_legality -verbose > "${REPORT_DIR}/06_placement_legality.rpt"

# Save placed design state
save_block -as "${DESIGN_NAME}_place"

# Placement QoR Reports
report_qor > "${REPORT_DIR}/06_place_qor.rpt"
report_timing -max_paths 10 > "${REPORT_DIR}/06_place_timing.rpt"
report_congestion > "${REPORT_DIR}/06_place_congestion.rpt"

echo "[FC_INFO] Placement and optimization completed."
