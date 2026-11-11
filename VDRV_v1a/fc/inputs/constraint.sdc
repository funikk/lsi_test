# ==============================================================================
# SDC Constraints for VDRV_v1a_core (Target: 100 MHz / 10.0 ns)
# Optimized for Synopsys Fusion Compiler (RTL-to-GDSII)
# ==============================================================================

# 1. Primary Clock Definition
create_clock -name clk -period 10.0000 [get_ports {clk}]
set_clock_uncertainty 0.2500 [get_clocks {clk}]
set_clock_transition 0.1500 [get_clocks {clk}]

# 2. Operating Conditions & Driving / Load Models (Configured per target library)
# If target library provides standard operating conditions:
# set_operating_conditions -analysis_type on_chip_variation
# set_driving_cell -lib_cell $DRIVING_CELL [remove_from_collection [all_inputs] [get_ports {clk}]]
# set_load -pin_load $OUTPUT_LOAD [all_outputs]

# 3. Memory Interface Delays (OpenRAM / Synchronous Memory Interface)
# Memory Input Delays (T_co ~ 3.5ns + 0.5ns margin = 4.0ns)
set_input_delay -clock clk 4.0000 [get_ports {imem_rdata_i* imem_ready_i dmem_rdata_i* dmem_ready_i}]

# Memory Output Delays (T_su ~ 1.5ns + 0.5ns margin = 2.0ns)
set_output_delay -clock clk 2.0000 [get_ports {imem_valid_o imem_addr_o* dmem_valid_o dmem_wstrb_o* dmem_addr_o* dmem_wdata_o* trap_out}]

# 4. Asynchronous / Low-Speed / Quasi-Static Signals
set_false_path -from [get_ports {rst_n}]
set_false_path -from [get_ports {uart_rx}]
set_false_path -to [get_ports {uart_tx}]
set_false_path -to [get_ports {mac_load_mode_en}]
set_false_path -to [get_ports {crc_load_mode_en}]
set_false_path -to [get_ports {cpu_load_state*}]

# 5. Reset Synchronizer Internal Cell Constraints
# Ensure skew/latency between back-to-back sync flip-flops is minimized
set_max_delay 2.0 -from [get_cells -hierarchical *u_reset_sync*u_dff1*] -to [get_cells -hierarchical *u_reset_sync*u_dff2*]
