// ==============================================================================
// VCS Simulation Filelist for VDRV_v1a Top HW/SW Co-Simulation
// ==============================================================================

// Include Directories
+incdir+../common/rtl
+incdir+../top/rtl
+incdir+../blocks/load_dma_subsys/rtl
+incdir+../blocks/load_sequencer/rtl
+incdir+../blocks/mac_load_core/rtl
+incdir+../blocks/crc_load_core/rtl
+incdir+../blocks/lfsr_prng/rtl
+incdir+../blocks/picorv32_cpu/rtl
+incdir+../blocks/uart_ctrl/rtl

// Common RTL & Behavioral Memories
../common/rtl/reset_sync.v
../common/rtl/imem.v
../common/rtl/dmem.v

// Sub-block RTL Modules
../blocks/uart_ctrl/rtl/uart_rx.v
../blocks/uart_ctrl/rtl/uart_tx.v
../blocks/uart_ctrl/rtl/uart_pkt_parser.v
../blocks/uart_ctrl/rtl/uart_ctrl.v
../blocks/load_sequencer/rtl/load_sequencer.v
../blocks/picorv32_cpu/rtl/picorv32.v
../blocks/lfsr_prng/rtl/lfsr_prng_ctrl.v
../blocks/mac_load_core/rtl/mac_unit.v
../blocks/mac_load_core/rtl/mac_array.v
../blocks/mac_load_core/rtl/mac_load_core.v
../blocks/crc_load_core/rtl/crc_channel.v
../blocks/crc_load_core/rtl/crc_load_core.v
../blocks/load_dma_subsys/rtl/load_dma_subsys.v

// Top Level Integration Modules
../top/rtl/VDRV_v1a_core.v
../top/rtl/VDRV_v1a_top.v

// Top Testbench
../top/tb/tb_VDRV_v1a_top.v
