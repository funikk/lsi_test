# Makefile for async_fifo project

# Tool definitions
VERILATOR = verilator
IVERILOG  = iverilog
VVP       = vvp
YOSYS     = yosys

# Directory definitions
RTL_DIR = rtl
TB_DIR  = tb
SIM_DIR = sim
SYN_DIR = syn
GLS_DIR = gls

# Source files
RTL_SRCS = $(RTL_DIR)/async_fifo.v
TB_SRCS  = $(TB_DIR)/tb_async_fifo.v
SYN_YS   = $(SYN_DIR)/run_synth.ys
SYN_NETLIST = $(SYN_DIR)/async_fifo_synth.v
SIM_CELLS = /usr/share/yosys/simlib.v

.PHONY: all lint rtl_sim syn gls_sim clean

all: lint rtl_sim syn gls_sim

# 1. Lint Check
lint:
	$(VERILATOR) --lint-only -Wall $(RTL_SRCS)

# 2. RTL Simulation
rtl_sim:
	cd $(SIM_DIR) && $(IVERILOG) -o rtl_sim.out ../$(TB_SRCS) ../$(RTL_SRCS)
	cd $(SIM_DIR) && $(VVP) rtl_sim.out

# 3. Logic Synthesis
syn:
	cd $(SYN_DIR) && $(YOSYS) -s run_synth.ys

# 4. Gate-Level Simulation (GLS)
gls_sim: syn
	$(IVERILOG) -DGATE_SIM -o gls_sim.out $(TB_SRCS) $(SYN_NETLIST) $(SIM_CELLS)
	$(VVP) gls_sim.out
	mv tb_async_fifo.vcd $(GLS_DIR)/ || true
	mv gls_sim.out $(GLS_DIR)/ || true

# 5. Clean up temporary files
clean:
	rm -f $(SIM_DIR)/rtl_sim.out $(SIM_DIR)/tb_async_fifo.vcd
	rm -f $(GLS_DIR)/gls_sim.out $(GLS_DIR)/tb_async_fifo.vcd
	rm -f $(SYN_DIR)/async_fifo_synth.v
