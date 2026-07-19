# Makefile for counter project

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
RTL_SRCS = $(RTL_DIR)/counter.v
TB_SRCS  = $(TB_DIR)/tb_counter.v
SYN_YS   = $(SYN_DIR)/run_synth.ys
SYN_NETLIST = $(SYN_DIR)/counter_synth.v
SIM_CELLS = /usr/share/yosys/simlib.v

.PHONY: all lint presynth_check rtl_sim syn gls_sim librelane librelane_qor clean

all: lint presynth_check rtl_sim syn gls_sim

# 1. Lint Check
lint:
	$(VERILATOR) --lint-only -Wall -Werror-MULTIDRIVEN -Wno-fatal $(RTL_SRCS)

# 2. Pre-Synthesis Fast Check
presynth_check:
	cd $(SYN_DIR) && $(YOSYS) -s presynth_check.ys

# 3. RTL Simulation
rtl_sim:
	cd $(SIM_DIR) && $(IVERILOG) -o rtl_sim.out ../$(TB_SRCS) ../$(RTL_SRCS)
	cd $(SIM_DIR) && $(VVP) rtl_sim.out

# 3. Logic Synthesis
syn:
	cd $(SYN_DIR) && $(YOSYS) -s run_synth.ys

# 4. Gate-Level Simulation (GLS)
gls_sim: syn
	$(IVERILOG) -o gls_sim.out $(TB_SRCS) $(SYN_NETLIST) $(SIM_CELLS)
	$(VVP) gls_sim.out
	mv tb_counter.vcd $(GLS_DIR)/ || true
	mv gls_sim.out $(GLS_DIR)/ || true

# 5. LibreLane PnR Flow
librelane:
	cd ../librelane && export PDK_ROOT=$$(pwd)/../pdks && export UV_PYTHON_INSTALL_DIR=$$(pwd)/.uv_python && export UV_CACHE_DIR=$$(pwd)/.uv_cache && uv run --python 3.12 python3 -m librelane -m $$(pwd)/.. --dockerized \
		--hide-progress-bar \
		--pdk-root $$(pwd)/../pdks \
		-p sky130A \
		-s sky130_fd_sc_hd \
		--run-tag run_100MHz \
		../librelane_designs/counter/config.json

# 6. LibreLane QoR Report
librelane_qor:
	../tools/report_librelane_qor_phases.py ../librelane_designs/counter/runs/run_100MHz

# 7. Clean up temporary files
clean:
	rm -f $(SIM_DIR)/rtl_sim.out $(SIM_DIR)/tb_counter.vcd
	rm -f $(GLS_DIR)/gls_sim.out $(GLS_DIR)/tb_counter.vcd
	rm -f $(SYN_DIR)/counter_synth.v

