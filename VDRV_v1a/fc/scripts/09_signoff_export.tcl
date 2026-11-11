# ==============================================================================
# 09_signoff_export.tcl - Final Signoff Analysis and Design Export
# ==============================================================================

echo "[FC_INFO] Starting signoff analysis and exporting physical deliverables..."

# 1. Signoff Timing Analysis
report_timing -delay_type min_max -max_paths 50 -significant_digits 4 > "${REPORT_DIR}/09_signoff_timing_all.rpt"
report_timing -delay_type max -max_paths 20 > "${REPORT_DIR}/09_signoff_timing_setup.rpt"
report_timing -delay_type min -max_paths 20 > "${REPORT_DIR}/09_signoff_timing_hold.rpt"

# 2. Area and Power Reports
report_area -hierarchy > "${REPORT_DIR}/09_signoff_area.rpt"
report_power -analysis_effort high > "${REPORT_DIR}/09_signoff_power.rpt"
report_qor > "${REPORT_DIR}/09_signoff_qor.rpt"

# 3. Export Physical Design Deliverables for Signoff / IR-Drop Analysis
echo "[FC_INFO] Exporting Netlist, DEF, and Parasitics..."

# Gate-level Verilog Netlist (for GLS or LVS)
write_verilog -include {pg_netlist} "${OUTPUT_DIR}/${DESIGN_NAME}.pg.v"
write_verilog -exclude {pg_objects} "${OUTPUT_DIR}/${DESIGN_NAME}.v"

# Design Exchange Format (DEF) (for IR-drop / RedHawk analysis)
write_def -version 5.8 "${OUTPUT_DIR}/${DESIGN_NAME}.def"

# Parasitics (SPEF)
write_parasitics -format SPEF "${OUTPUT_DIR}/${DESIGN_NAME}.spef"

# Stream format (GDSII / OASIS) if stream map is configured
if {[info exists ::env(FC_MAP_FILE)] && [file exists $::env(FC_MAP_FILE)]} {
    write_gds -layer_map $::env(FC_MAP_FILE) "${OUTPUT_DIR}/${DESIGN_NAME}.gds"
}

# Save final signoff block
save_block -as "${DESIGN_NAME}_signoff"

echo "========================================================================"
echo " [SUCCESS] Fusion Compiler Full Implementation Flow Completed!"
echo " Results available in:"
echo "   - Reports:    ${REPORT_DIR}"
echo "   - Outputs:    ${OUTPUT_DIR}"
echo "========================================================================"
