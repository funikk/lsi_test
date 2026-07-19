# async_fifo.sdc
# Synopsys Design Constraints (SDC) for Asynchronous FIFO

# 1. Clock Definitions
# Define independent write and read clocks
# wr_clk: 100 MHz (10.0 ns period)
create_clock -name wr_clk -period 10.0 [get_ports wr_clk]

# rd_clk: 40 MHz (25.0 ns period)
create_clock -name rd_clk -period 25.0 [get_ports rd_clk]

# 2. Clock Domain Crossing (CDC) Constraints
# Specify that wr_clk and rd_clk are asynchronous to each other.
# This prevents the static timing analysis (STA) tool from analyzing paths
# crossing between these two clock domains, representing standard CDC best practices.
set_clock_groups -asynchronous -group [get_clocks wr_clk] -group [get_clocks rd_clk]

# 3. Clock Uncertainty & Transition
set_clock_uncertainty 0.2 [get_clocks wr_clk]
set_clock_uncertainty 0.2 [get_clocks rd_clk]

set_clock_transition 0.1 [get_clocks wr_clk]
set_clock_transition 0.1 [get_clocks rd_clk]

# 4. Input Delays
# Constrain inputs relative to their respective clocks
set_wr_inputs [get_ports {wr_en data_in[*]}]
set_input_delay -max 3.0 -clock wr_clk $set_wr_inputs
set_input_delay -min 0.5 -clock wr_clk $set_wr_inputs

set_rd_inputs [get_ports {rd_en}]
set_input_delay -max 5.0 -clock rd_clk $set_rd_inputs
set_input_delay -min 0.5 -clock rd_clk $set_rd_inputs

# 5. Output Delays
# Constrain outputs relative to their respective clocks
set_output_delay -max 3.0 -clock wr_clk [get_ports wr_full]
set_output_delay -min 0.5 -clock wr_clk [get_ports wr_full]

set_rd_outputs [get_ports {data_out[*] rd_empty}]
set_output_delay -max 5.0 -clock rd_clk $set_rd_outputs
set_output_delay -min 0.5 -clock rd_clk $set_rd_outputs

# 6. Physical Design Constraints
set_max_fanout 20 [current_design]
set_max_transition 0.5 [current_design]
