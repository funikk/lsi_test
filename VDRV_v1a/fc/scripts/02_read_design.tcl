# ==============================================================================
# 02_read_design.tcl - Read RTL Sources (Analyze & Elaborate)
# ==============================================================================

echo "[FC_INFO] Reading RTL source files..."

# List of Verilog RTL files for VDRV_v1a_core
set rtl_files [list \
    "${RTL_DIR}/common/rtl/reset_sync.v" \
    "${RTL_DIR}/blocks/uart_ctrl/rtl/uart_rx.v" \
    "${RTL_DIR}/blocks/uart_ctrl/rtl/uart_tx.v" \
    "${RTL_DIR}/blocks/uart_ctrl/rtl/uart_pkt_parser.v" \
    "${RTL_DIR}/blocks/uart_ctrl/rtl/uart_ctrl.v" \
    "${RTL_DIR}/blocks/load_sequencer/rtl/load_sequencer.v" \
    "${RTL_DIR}/blocks/picorv32_cpu/rtl/picorv32.v" \
    "${RTL_DIR}/blocks/lfsr_prng/rtl/lfsr_prng_ctrl.v" \
    "${RTL_DIR}/blocks/mac_load_core/rtl/mac_unit.v" \
    "${RTL_DIR}/blocks/mac_load_core/rtl/mac_array.v" \
    "${RTL_DIR}/blocks/mac_load_core/rtl/mac_load_core.v" \
    "${RTL_DIR}/blocks/crc_load_core/rtl/crc_channel.v" \
    "${RTL_DIR}/blocks/crc_load_core/rtl/crc_load_core.v" \
    "${RTL_DIR}/blocks/load_dma_subsys/rtl/load_dma_subsys.v" \
    "${RTL_DIR}/top/rtl/VDRV_v1a_core.v" \
]

# Analyze Verilog RTL
analyze -format verilog $rtl_files

# Elaborate Top Module
elaborate $DESIGN_NAME

# Set Current Design and Link
current_design $DESIGN_NAME
link

echo "[FC_INFO] Elaborated and linked design: [get_object_name [current_design]]"
