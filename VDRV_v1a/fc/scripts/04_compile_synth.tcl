# ==============================================================================
# 04_compile_synth.tcl - Logic Synthesis & Initial Pre-Layout Optimization
# ==============================================================================

echo "[FC_INFO] Starting logic synthesis (compile_fusion)..."

# Synthesis Configuration
set_app_options -name compile.fusion.flow -value "standard"

# Perform logic synthesis and initial optimization
compile_fusion -to initial_opto

# Save synthesized design state
save_block -as "${DESIGN_NAME}_synth"

# Initial QoR Reports
report_qor > "${REPORT_DIR}/04_synth_qor.rpt"
report_timing -max_paths 10 > "${REPORT_DIR}/04_synth_timing.rpt"
report_area -hierarchy > "${REPORT_DIR}/04_synth_area.rpt"

echo "[FC_INFO] Logic synthesis completed successfully."
