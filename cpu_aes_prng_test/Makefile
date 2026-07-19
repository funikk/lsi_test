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
           $(RTL_DIR)/cpu_aes_prng_top.v

TB_SRCS  = $(TB_DIR)/tb_cpu_aes_prng.v
SYN_YS   = $(SYN_DIR)/run_synth.ys
SYN_NETLIST = $(SYN_DIR)/cpu_aes_prng_top_synth.v
SIM_CELLS = /usr/share/yosys/simlib.v

.PHONY: all firmware lint rtl_sim syn gls_sim clean

all: firmware lint rtl_sim syn gls_sim

firmware:
	$(MAKE) -C $(FW_DIR)
	cp $(FW_DIR)/firmware.hex $(SIM_DIR)/firmware.hex
	cp $(FW_DIR)/firmware.hex $(SYN_DIR)/firmware.hex

lint:
	$(VERILATOR) --lint-only -Wall -Wno-fatal $(RTL_SRCS)

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

clean:
	$(MAKE) -C $(FW_DIR) clean
	rm -f $(SIM_DIR)/rtl_sim.out $(SIM_DIR)/tb_cpu_aes_prng.vcd $(SIM_DIR)/firmware.hex
	rm -f $(GLS_DIR)/gls_sim.out $(GLS_DIR)/tb_cpu_aes_prng.vcd
	rm -f $(SYN_DIR)/cpu_aes_prng_top_synth.v $(SYN_DIR)/firmware.hex
