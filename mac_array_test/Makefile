# Makefile for MAC Array project

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
RTL_SRCS = $(RTL_DIR)/mac_unit.v $(RTL_DIR)/mac_array.v
TB_SRCS  = $(TB_DIR)/tb_mac_array.v
SYN_YS   = $(SYN_DIR)/run_synth.ys
SYN_NETLIST = $(SYN_DIR)/mac_array_synth.v
SIM_CELLS = /usr/share/yosys/simlib.v

.PHONY: all lint presynth_check rtl_sim syn gls_sim pnr pnr_qor clean

all: lint presynth_check rtl_sim syn gls_sim

# 1. Lint Check
lint:
	$(VERILATOR) --lint-only -Wall -Werror-MULTIDRIVEN -Wno-fatal $(RTL_SRCS)

# 2. Pre-Synthesis Fast Check
presynth_check:
	cd $(SYN_DIR) && $(YOSYS) -s presynth_check.ys

# 3. RTL Simulation
rtl_sim:
	cd $(SIM_DIR) && $(IVERILOG) -o rtl_sim.out $(addprefix ../, $(TB_SRCS)) $(addprefix ../, $(RTL_SRCS))
	cd $(SIM_DIR) && $(VVP) rtl_sim.out

# 3. Logic Synthesis
syn:
	cd $(SYN_DIR) && $(YOSYS) -s run_synth.ys

# 4. Gate-Level Simulation (GLS)
gls_sim: syn
	$(IVERILOG) -DGATE_SIM -o gls_sim.out $(TB_SRCS) $(SYN_NETLIST) $(SIM_CELLS)
	$(VVP) gls_sim.out
	mv tb_mac_array.vcd $(GLS_DIR)/ || true
	mv gls_sim.out $(GLS_DIR)/ || true

# 5. PnR Flow
pnr:
	python3 ../tools/run_pnr.py mac_array

# 6. PnR QoR Report
pnr_qor:
	../tools/report_qor_phases.py ../librelane_designs/mac_array/runs/run_100MHz

# 7. Clean up temporary files
clean:
	rm -f $(SIM_DIR)/rtl_sim.out $(SIM_DIR)/tb_mac_array.vcd
	rm -f $(GLS_DIR)/gls_sim.out $(GLS_DIR)/tb_mac_array.vcd
	rm -f $(SYN_DIR)/mac_array_synth.v

