# ==============================================================================
# 01_lib_setup.tcl - PDK and Reference Library Configuration (NDM / Tech)
# ==============================================================================

# Create workspace design library
set DESIGN_LIB "${WORK_DIR}/${DESIGN_NAME}_lib"
if {[file exists $DESIGN_LIB]} {
    file delete -force $DESIGN_LIB
}

# Determine Reference Libraries (NDM format)
set ref_libs [list]

if {[info exists ::env(FC_NDM_LIBS)] && $::env(FC_NDM_LIBS) ne ""} {
    set ref_libs $::env(FC_NDM_LIBS)
    echo "[FC_INFO] Loaded reference libraries from FC_NDM_LIBS: $ref_libs"
} else {
    echo "[FC_WARN] FC_NDM_LIBS environment variable is not defined!"
    echo "[FC_WARN] Please configure FC_NDM_LIBS in fc_env.sh with your Foundry PDK NDM libraries."
    echo "[FC_WARN] For syntax checking or mock dry-runs, attempting to continue..."
}

# Create Design Library with technology information
if {[info exists ::env(FC_TECH_FILE)] && [file exists $::env(FC_TECH_FILE)]} {
    create_lib $DESIGN_LIB -tech $::env(FC_TECH_FILE) -ref_libs $ref_libs
} elseif {[llength $ref_libs] > 0} {
    create_lib $DESIGN_LIB -ref_libs $ref_libs
} else {
    # Fallback dry-run library creation
    create_lib $DESIGN_LIB
}

# TLUPlus Parasitic Extraction setup (if available)
if {[info exists ::env(FC_TLUPLUS_MAX)] && [file exists $::env(FC_TLUPLUS_MAX)]} {
    set_parasitic_parameters -early_spec $::env(FC_TLUPLUS_MIN) -late_spec $::env(FC_TLUPLUS_MAX)
}

echo "[FC_INFO] Library setup finished: $DESIGN_LIB"
