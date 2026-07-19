# aes_prng.sdc
# Synopsys Design Constraints (SDC) for aes_prng_top

# 1. Clock Definition
# Define system clock 'clk' with period 10.0 ns (100 MHz)
create_clock -name clk -period 10.0 [get_ports clk]

# 2. Clock Constraints
# Clock Uncertainty: account for clock jitter/skew (200 ps for setup/hold)
set_clock_uncertainty 0.2 [get_clocks clk]

# Clock Transition: define clock rise/fall transition time (100 ps)
set_clock_transition 0.1 [get_clocks clk]

# 3. Input Delays (Constraint for inputs arriving relative to the clock)
# We exclude the clock port itself from the input delays list.
set_inputs [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay -max 3.0 -clock clk $set_inputs
set_input_delay -min 0.5 -clock clk $set_inputs

# 4. Output Delays (Constraint for outputs driven relative to the clock)
set_output_delay -max 3.0 -clock clk [all_outputs]
set_output_delay -min 0.5 -clock clk [all_outputs]

# 5. Environmental Constraints
# Max Fanout constraint for registers
set_max_fanout 20 [current_design]

# Max Transition constraint
set_max_transition 0.5 [current_design]
