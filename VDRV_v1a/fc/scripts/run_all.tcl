# ==============================================================================
# run_all.tcl - Top-Level Batch Execution Script for Fusion Compiler
# ==============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]

echo "[FC_FLOW] >>> Step 0: Common Setup"
source "${SCRIPT_DIR}/00_common_setup.tcl"

echo "[FC_FLOW] >>> Step 1: Library Setup"
source "${SCRIPT_DIR}/01_lib_setup.tcl"

echo "[FC_FLOW] >>> Step 2: Read Design RTL"
source "${SCRIPT_DIR}/02_read_design.tcl"

echo "[FC_FLOW] >>> Step 3: Apply Constraints"
source "${SCRIPT_DIR}/03_constraints.tcl"

echo "[FC_FLOW] >>> Step 4: Logic Synthesis & Compile"
source "${SCRIPT_DIR}/04_compile_synth.tcl"

echo "[FC_FLOW] >>> Step 5: Floorplan, PG Mesh & Pin Placement"
source "${SCRIPT_DIR}/05_floorplan.tcl"

echo "[FC_FLOW] >>> Step 6: Standard Cell Placement & Opt"
source "${SCRIPT_DIR}/06_place_opt.tcl"

echo "[FC_FLOW] >>> Step 7: Clock Tree Synthesis (CTS)"
source "${SCRIPT_DIR}/07_cts_opt.tcl"

echo "[FC_FLOW] >>> Step 8: Global & Detail Routing"
source "${SCRIPT_DIR}/08_route_opt.tcl"

echo "[FC_FLOW] >>> Step 9: Signoff Analysis & Export"
source "${SCRIPT_DIR}/09_signoff_export.tcl"

echo "[FC_FLOW] >>> ALL FUSION COMPILER STEPS COMPLETED SUCCESSFULLY!"
exit 0
