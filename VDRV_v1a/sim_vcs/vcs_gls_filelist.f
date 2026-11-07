// ==============================================================================
// VCS Gate-Level Simulation (GLS) Filelist for VDRV_v1a
// Note: Core module (VDRV_v1a_core) is replaced with synthesized/PnR netlist
// ==============================================================================

// Include Directories
+incdir+../common/rtl
+incdir+../top/rtl

// Behavioral Memories & Top Wrapper
../common/rtl/imem.v
../common/rtl/dmem.v
../top/rtl/VDRV_v1a_top.v

// System Testbench
../top/tb/tb_VDRV_v1a_top.v
