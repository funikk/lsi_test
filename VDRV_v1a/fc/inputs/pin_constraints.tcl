# ==============================================================================
# Pin Placement Constraints for Fusion Compiler (VDRV_v1a_core)
# Corresponds to pnr/pin_order.cfg
# ==============================================================================

# Reset existing pin constraints
remove_individual_pin_constraints -all
remove_block_pin_constraints

# Allowed routing metal layers for pins (customized depending on PDK, e.g., M3, M4)
set pin_horiz_layers [list M3 M5]
set pin_vert_layers  [list M2 M4]

# 1. North Boundary (Top side)
# Clock, Reset, Trap, Sequencer Status
set north_pins [get_ports [list \
    clk \
    rst_n \
    trap_out \
    mac_load_mode_en \
    crc_load_mode_en \
    cpu_load_state[*] \
]]
set_individual_pin_constraints -ports $north_pins -sides top -allowed_layers $pin_horiz_layers

# 2. South Boundary (Bottom side)
# UART Interface
set south_pins [get_ports [list \
    uart_rx \
    uart_tx \
]]
set_individual_pin_constraints -ports $south_pins -sides bottom -allowed_layers $pin_horiz_layers

# 3. West Boundary (Left side)
# IMEM Interface
set west_pins [get_ports [list \
    imem_valid_o \
    imem_addr_o[*] \
    imem_rdata_i[*] \
    imem_ready_i \
]]
set_individual_pin_constraints -ports $west_pins -sides left -allowed_layers $pin_vert_layers

# 4. East Boundary (Right side)
# DMEM Interface
set east_pins [get_ports [list \
    dmem_valid_o \
    dmem_wstrb_o[*] \
    dmem_addr_o[*] \
    dmem_wdata_o[*] \
    dmem_rdata_i[*] \
    dmem_ready_i \
]]
set_individual_pin_constraints -ports $east_pins -sides right -allowed_layers $pin_vert_layers

# Global pin placement guidance
set_block_pin_constraints -corner_keepout_distance 10.0 -pin_spacing 2.0
