# Makefile for CPU + AES PRNG project

VERILATOR = verilator
IVERILOG  = iverilog
VVP       = vvp
YOSYS     = yosys
PYTHON    = python3

RTL_DIR = rtl
TB_DIR  = tb
SIM_DIR = sim
SYN_DIR = syn
GLS_DIR = gls
FW_DIR  = firmware

RTL_SRCS = $(RTL_DIR)/picorv32.v \
           $(RTL_DIR)/aes_sbox.v \
           $(RTL_DIR)/aes_core.v \
           $(RTL_DIR)/lfsr_prng_ctrl.v \
           $(RTL_DIR)/aes_dma_subsys.v \
           $(RTL_DIR)/cpu_aes_prng_core.v \
           $(RTL_DIR)/imem.v \
           $(RTL_DIR)/dmem.v \
           $(RTL_DIR)/reset_sync.v \
           $(RTL_DIR)/cpu_aes_prng_top.v

TB_SRCS  = $(TB_DIR)/tb_cpu_aes_prng.v
SYN_YS   = $(SYN_DIR)/run_synth.ys
SYN_NETLIST = $(SYN_DIR)/cpu_aes_prng_top_syn.v
SIM_CELLS = /usr/share/yosys/simlib.v

.PHONY: all firmware lint presynth_check rtl_sim syn gls_sim librelane librelane_qor clean

all: firmware lint rtl_sim syn gls_sim

firmware:
	$(MAKE) -C $(FW_DIR)
	cp $(FW_DIR)/firmware.hex $(SIM_DIR)/firmware.hex
	cp $(FW_DIR)/firmware.hex $(SYN_DIR)/firmware.hex

lint:
	$(VERILATOR) --lint-only -Wall -Werror-MULTIDRIVEN -Wno-fatal $(RTL_SRCS)

presynth_check:
	cd $(SYN_DIR) && $(YOSYS) -s presynth_check.ys

rtl_sim: firmware
	cd $(SIM_DIR) && $(IVERILOG) -o rtl_sim.out $(addprefix ../, $(TB_SRCS)) $(addprefix ../, $(RTL_SRCS))
	cd $(SIM_DIR) && $(VVP) rtl_sim.out

syn: firmware
	cd $(SYN_DIR) && $(YOSYS) -s run_synth.ys

gls_sim: syn firmware
	cd $(SIM_DIR) && $(IVERILOG) -DGATE_SIM -o gls_sim.out ../$(TB_SRCS) ../$(SYN_NETLIST) $(SIM_CELLS)
	cd $(SIM_DIR) && $(VVP) gls_sim.out
	mv $(SIM_DIR)/tb_cpu_aes_prng.vcd $(GLS_DIR)/ || true
	mv $(SIM_DIR)/gls_sim.out $(GLS_DIR)/ || true

librelane:
	cd ../librelane && export PDK_ROOT=$$(pwd)/../pdks && export UV_PYTHON_INSTALL_DIR=$$(pwd)/.uv_python && export UV_CACHE_DIR=$$(pwd)/.uv_cache && uv run --python 3.12 python3 -m librelane -m $$(pwd)/.. --dockerized \
		--hide-progress-bar \
		--pdk-root $$(pwd)/../pdks \
		-p sky130A \
		-s sky130_fd_sc_hs \
		--run-tag run_100MHz_hs \
		../librelane_designs/cpu_aes_prng_core/config.json

librelane_qor:
	../tools/report_librelane_qor_phases.py ../librelane_designs/cpu_aes_prng_core/runs/run_100MHz_hs

clean:
	$(MAKE) -C $(FW_DIR) clean
	rm -f $(SIM_DIR)/rtl_sim.out $(SIM_DIR)/tb_cpu_aes_prng.vcd $(SIM_DIR)/firmware.hex
	rm -f $(GLS_DIR)/gls_sim.out $(GLS_DIR)/tb_cpu_aes_prng.vcd
	rm -f $(SYN_DIR)/cpu_aes_prng_top_syn.v $(SYN_DIR)/cpu_aes_prng_top_synth.v $(SYN_DIR)/firmware.hex

