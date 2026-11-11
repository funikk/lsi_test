# ==============================================================================
# 08_route_opt.tcl - Global/Detail Routing and Post-Route Timing Optimization
# ==============================================================================

echo "[FC_INFO] Starting routing and post-route optimization..."

# Check routing prerequisites
check_routability

# Run Auto Routing
route_auto

# Run Post-Route Optimization (Timing, Crosstalk, SI)
route_opt

# Save routed design state
save_block -as "${DESIGN_NAME}_route"

# DRC and Routing Verification
check_routes > "${REPORT_DIR}/08_route_drc.rpt"
check_lvs > "${REPORT_DIR}/08_route_lvs.rpt"

# Post-Route QoR Reports
report_qor > "${REPORT_DIR}/08_route_qor.rpt"
report_timing -delay_type min_max -max_paths 20 > "${REPORT_DIR}/08_route_timing.rpt"

echo "[FC_INFO] Routing and post-route optimization completed."
