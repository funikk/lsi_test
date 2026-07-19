# sync_fifo.sdc
# Synopsys Design Constraints (SDC) for sync_fifo

# 1. Unit definition (optional, but good practice for clarity)
# Units: time = ns, resistance = kohm, capacitance = fF, voltage = V, current = mA

# 2. Clock Definition
# Define a system clock 'clk' with a period of 10.0 ns (100 MHz frequency)
# and a 50% duty cycle (0.0 ns rise, 5.0 ns fall).
create_clock -name clk -period 10.0 [get_ports clk]

# 3. Clock Constraints
# Clock Uncertainty: account for clock jitter and skew (e.g., 200 ps for setup/hold)
set_clock_uncertainty 0.2 [get_clocks clk]

# Clock Transition: define clock rise/fall transition time (slew rate) of 100 ps
set_clock_transition 0.1 [get_clocks clk]

# 4. Input Delays (Constraint for inputs arriving relative to the clock)
# Assuming maximum input external delay of 3.0 ns (30% of clock cycle) for setup timing.
# Assuming minimum input external delay of 0.5 ns for hold timing.
# We exclude the clock port itself from the input delays list.
set_inputs [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay -max 3.0 -clock clk $set_inputs
set_input_delay -min 0.5 -clock clk $set_inputs

# 5. Output Delays (Constraint for outputs driven relative to the clock)
# Assuming maximum external path delay of 3.0 ns required by the next block.
# Assuming minimum external path delay of 0.5 ns.
set_output_delay -max 3.0 -clock clk [all_outputs]
set_output_delay -min 0.5 -clock clk [all_outputs]

# 6. Environmental Constraints (Commonly used in ASIC/FPGA synthesis & PnR)
# Max Fanout constraint for registers (limits how many gates a single pin can drive)
set_max_fanout 20 [current_design]

# Max Transition constraint (limits transition time on nets to prevent slow rising/falling edges)
set_max_transition 0.5 [current_design]
