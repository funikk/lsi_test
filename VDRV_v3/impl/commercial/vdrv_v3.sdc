## ==============================================================================
## Synopsys Design Constraints (SDC 2.1) Template for VDRV_v3
## Target Process: Commercial 40nm PDK (e.g., TSMC 40nm LP/ULP)
## Operating Target: 200 MHz (5.0 ns period) IR-Aware STA Stress Motif
## ==============================================================================

# 1. Primary Clock Definition
# ------------------------------------------------------------------------------
set CLK_NAME     "clk"
set CLK_PERIOD   5.000   ;# 200 MHz target for 40nm commercial logic
set CLK_UNCERT   0.200   ;# Clock uncertainty (jitter + margin)
set CLK_TRANS    0.080   ;# Max clock transition

create_clock -name ${CLK_NAME} -period ${CLK_PERIOD} [get_ports clk]
set_clock_uncertainty ${CLK_UNCERT} [get_clocks ${CLK_NAME}]
set_clock_transition  ${CLK_TRANS}  [get_clocks ${CLK_NAME}]

# 2. Clock Gating Constraints
# ------------------------------------------------------------------------------
# Ensure hold / setup margin on integrated clock gating (ICG) enable pins
set_clock_gating_check -setup 0.200 -hold 0.100 [get_clocks ${CLK_NAME}]

# 3. Input Delays (Assuming 20% budget outside)
# ------------------------------------------------------------------------------
set IN_DELAY [expr ${CLK_PERIOD} * 0.20]
set OUT_DELAY [expr ${CLK_PERIOD} * 0.20]

set ALL_INPUTS_EXCL_CLK [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay -clock ${CLK_NAME} -max ${IN_DELAY} ${ALL_INPUTS_EXCL_CLK}
set_input_delay -clock ${CLK_NAME} -min 0.100       ${ALL_INPUTS_EXCL_CLK}

# 4. Output Delays
# ------------------------------------------------------------------------------
set_output_delay -clock ${CLK_NAME} -max ${OUT_DELAY} [all_outputs]
set_output_delay -clock ${CLK_NAME} -min 0.100        [all_outputs]

# 5. False Paths & Asynchronous Exceptions
# ------------------------------------------------------------------------------
# Asynchronous master reset
set_false_path -from [get_ports rst_n]

# Quasi-static configuration and pins
set_false_path -from [get_ports scenario_sel[*]]
set_false_path -from [get_ports uart_rx]
set_false_path -to   [get_ports uart_tx]

# Power switch acknowledgment signals are asynchronous / multi-cycle feedback
set_false_path -from [get_ports sw_trickle_ack[*]]
set_false_path -from [get_ports sw_main_ack[*]]

# 6. Physical Stress Exceptions (EM Stress Block Preservation)
# ------------------------------------------------------------------------------
# Prohibit buffer tree optimization on the high-fanout net inside em_stress
# to force maximum driver current concentration on commercial metal wires:
set_dont_touch [get_cells -hierarchical -filter "name =~ *u_em_stress*u_fo*r_drvr*"]
set_max_fanout 128 [get_pins -hierarchical -filter "name =~ *u_em_stress*u_fo*r_drvr*/Q"]

# 7. Operating Conditions & Environmental Margins
# ------------------------------------------------------------------------------
# Margin for dynamic IR-drop induced timing degradation
set_timing_derate -early 0.95 -cell_delay
set_timing_derate -late  1.05 -cell_delay
