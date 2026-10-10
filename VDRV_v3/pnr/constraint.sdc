# SDC Constraints for VDRV_v3_core (Target: 100 MHz / 10.0 ns)
# Process: SkyWater 130nm (sky130_fd_sc_hs)

# 1. Primary Clock Definition
create_clock -name clk -period 10.0000 [get_ports {clk}]
set_clock_uncertainty 0.2500 [get_clocks {clk}]
set_clock_transition 0.1500 [get_clocks {clk}]

# 2. Memory Interface Delays (OpenRAM sky130 timing model)
# Memory Input Delays (T_co ~ 3.5ns + 0.5ns margin = 4.0ns)
set_input_delay -clock clk 4.0000 [get_ports {imem_rdata_i* imem_ready_i dmem_rdata_i* dmem_ready_i}]

# Memory Output Delays (T_su ~ 1.5ns + 0.5ns margin = 2.0ns)
set_output_delay -clock clk 2.0000 [get_ports {imem_valid_o imem_addr_o* dmem_valid_o dmem_wstrb_o* dmem_addr_o* dmem_wdata_o* trap_out}]

# 3. Asynchronous / Low-Speed Signals (Avoid excessive timing pressure)
set_false_path -from [get_ports {rst_n}]
set_false_path -from [get_ports {scenario_sel*}]
set_false_path -from [get_ports {uart_rx}]
set_false_path -to   [get_ports {uart_tx}]
set_false_path -to   [get_ports {scenario_done sig_ok sig_out* marker*}]
set_false_path -from [get_ports {sw_trickle_ack* sw_main_ack*}]
set_false_path -to   [get_ports {sw_trickle_en* sw_main_en*}]

# 4. Reset Synchronizer Internal Cell Constraint
set_max_delay 2.0 -from [get_cells -hierarchical *u_reset_sync*u_dff1*] -to [get_cells -hierarchical *u_reset_sync*u_dff2*]
