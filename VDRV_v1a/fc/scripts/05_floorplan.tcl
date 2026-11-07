# ==============================================================================
# 05_floorplan.tcl - Floorplan, Power Network (PG Mesh), and Pin Placement
# ==============================================================================

echo "[FC_INFO] Initializing floorplan..."

# Core utilization ~ 40%, aspect ratio 1.0, 10um core-to-die offset
initialize_floorplan \
    -core_utilization 0.40 \
    -core_offset {10 10 10 10} \
    -flip_first_row true

# Connect global power and ground nets
set_app_options -name plan.pgrouting.auto_create_pg_net -value true
create_net -power VDD
create_net -ground VSS

connect_pg_net -net VDD [get_pins -hierarchical */VDD]
connect_pg_net -net VSS [get_pins -hierarchical */VSS]

# Apply Pin Placement Constraints
if {[file exists "${INPUT_DIR}/pin_constraints.tcl"]} {
    source "${INPUT_DIR}/pin_constraints.tcl"
    place_pins -self
    echo "[FC_INFO] Pin placement completed."
}

# ------------------------------------------------------------------------------
# Power Network Synthesis (PG Mesh / Straps for IR-Drop Evaluation)
# ------------------------------------------------------------------------------
# Note: Layer names (e.g. M1, M4, M5) should align with the loaded PDK technology
echo "[FC_INFO] Creating Power & Ground mesh..."

# Template Power Mesh Strategy (Customizable for dynamic IR-drop experiments)
catch {
    create_pg_mesh_pattern pg_mesh_pat \
        -layers { \
            { {horizontal_layer: M4} {width: 1.2} {spacing: interleaving} {pitch: 20.0} } \
            { {vertical_layer:   M5} {width: 1.6} {spacing: interleaving} {pitch: 20.0} } \
        }

    set_pg_strategy core_pg_strategy -pattern { {name: pg_mesh_pat} {nets: {VDD VSS}} }
    compile_pg -strategies core_pg_strategy
}

# Save floorplanned design state
save_block -as "${DESIGN_NAME}_floorplan"
report_utilization > "${REPORT_DIR}/05_floorplan_util.rpt"

echo "[FC_INFO] Floorplan initialization finished."
