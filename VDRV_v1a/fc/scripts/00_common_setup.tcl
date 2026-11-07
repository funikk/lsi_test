# ==============================================================================
# 00_common_setup.tcl - Global Environment and Variable Definitions
# ==============================================================================

# Design Information
set DESIGN_NAME           "VDRV_v1a_core"
set CLK_PERIOD            10.0000; # 100 MHz target
set CLK_UNCERTAINTY       0.2500;
set CLK_TRANSITION        0.1500;

# Directory Structure (relative to fc/ work directory)
set SCRIPT_DIR            [file normalize [file dirname [info script]]]
set ROOT_DIR              [file normalize "${SCRIPT_DIR}/.."]
set WORK_DIR              "${ROOT_DIR}/work"
set REPORT_DIR            "${ROOT_DIR}/reports"
set OUTPUT_DIR            "${ROOT_DIR}/outputs"
set INPUT_DIR             "${ROOT_DIR}/inputs"
set RTL_DIR               [file normalize "${ROOT_DIR}/.."]

file mkdir $WORK_DIR
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR

# Multi-threading Setup
if {[info exists ::env(FC_NUM_CORES)]} {
    set_host_options -max_cores $::env(FC_NUM_CORES)
} else {
    set_host_options -max_cores 8
}

# Message and Log Reporting settings
set_app_options -name search_path -value [list \
    . \
    $INPUT_DIR \
    "${RTL_DIR}/common/rtl" \
    "${RTL_DIR}/top/rtl" \
    "${RTL_DIR}/blocks/load_dma_subsys/rtl" \
    "${RTL_DIR}/blocks/load_sequencer/rtl" \
    "${RTL_DIR}/blocks/mac_load_core/rtl" \
    "${RTL_DIR}/blocks/crc_load_core/rtl" \
    "${RTL_DIR}/blocks/lfsr_prng/rtl" \
    "${RTL_DIR}/blocks/picorv32_cpu/rtl" \
    "${RTL_DIR}/blocks/uart_ctrl/rtl" \
]

echo "[FC_INFO] Global setup completed. Design: ${DESIGN_NAME}"
