# SDC Constraints for cpu_aes_prng_core (Target: 100 MHz / 10.0 ns)
# Process: SkyWater 130nm (sky130_fd_sc_hs)

create_clock -name clk -period 10.0000 [get_ports {clk}]
set_clock_uncertainty 0.2500 [get_clocks {clk}]
set_clock_transition 0.1500 [get_clocks {clk}]

# Memory interface input delays based on OpenRAM sky130 (T_co ~ 3.5ns + 0.5ns margin = 4.0ns)
set_input_delay -clock clk 4.0000 [get_ports {imem_rdata_i* imem_ready_i dmem_rdata_i* dmem_ready_i}]

# Memory interface output delays based on OpenRAM sky130 (T_su ~ 1.5ns + 0.5ns margin = 2.0ns)
set_output_delay -clock clk 2.0000 [get_ports {imem_valid_o imem_addr_o* dmem_valid_o dmem_wstrb_o* dmem_addr_o* dmem_wdata_o* trap_out}]

# -----------------------------------------------------------------------------
# Reset Synchronizer Constraints (Direct S/C Instantiation: \u_reset_sync.u_dff1 )
# -----------------------------------------------------------------------------
# Asynchronous Reset Input False Path
set_false_path -from [get_ports {rst_n}]

# Bound Inter-stage Delay Between Synchronizer DFFs (2.0 ns max)
set_max_delay 2.0 -from [get_cells -hierarchical *u_reset_sync*u_dff1*] -to [get_cells -hierarchical *u_reset_sync*u_dff2*]

