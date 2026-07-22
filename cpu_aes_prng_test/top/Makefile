IVERILOG  := iverilog
VVP       := vvp
VERILATOR := verilator
YOSYS     := yosys

SIM_DIR := sim
SYN_DIR := syn
GLS_DIR := gls
RTL_DIR := rtl
TB_DIR  := tb
FW_DIR  := ../firmware

RTL_SRCS := ../common/rtl/imem.v \
            ../common/rtl/dmem.v \
            ../common/rtl/reset_sync.v \
            ../blocks/picorv32_cpu/rtl/picorv32.v \
            ../blocks/aes_core/rtl/aes_sbox.v \
            ../blocks/aes_core/rtl/aes_core.v \
            ../blocks/lfsr_prng/rtl/lfsr_prng_ctrl.v \
            ../blocks/aes_dma_subsys/rtl/aes_dma_subsys.v \
            rtl/cpu_aes_prng_core.v \
            rtl/cpu_aes_prng_top.v

TB_SRCS     := tb/tb_cpu_aes_prng.v
SYN_NETLIST := $(SYN_DIR)/cpu_aes_prng_top_syn.v
SIM_CELLS   := /usr/share/yosys/simlib.v

INCLUDES := -Irtl -I../common/rtl -I../blocks/picorv32_cpu/rtl -I../blocks/aes_core/rtl -I../blocks/lfsr_prng/rtl -I../blocks/aes_dma_subsys/rtl

.PHONY: all firmware lint presynth_check rtl_sim syn gls_sim clean

all: firmware lint rtl_sim syn gls_sim

firmware:
	$(MAKE) -C $(FW_DIR)
	@mkdir -p $(SIM_DIR) $(SYN_DIR)
	cp $(FW_DIR)/firmware.hex $(SIM_DIR)/firmware.hex
	cp $(FW_DIR)/firmware.hex $(SYN_DIR)/firmware.hex

lint:
	@echo "[LINT] Checking top-level integration..."
	$(VERILATOR) --lint-only -Wall -Werror-MULTIDRIVEN -Wno-fatal $(INCLUDES) $(RTL_SRCS)

presynth_check:
	@mkdir -p $(SYN_DIR)
	@echo "[PRESYNTH] Running fast Yosys AST check on top level..."
	cd $(SYN_DIR) && $(YOSYS) -p "read_verilog $(addprefix -I../, $(INCLUDES)) $(addprefix ../, $(RTL_SRCS)); proc; check -assert" > presynth.log

rtl_sim: firmware
	@mkdir -p $(SIM_DIR)
	@echo "[SIM] Building top-level system simulation..."
	cd $(SIM_DIR) && $(IVERILOG) -g2012 $(addprefix -I../, $(INCLUDES)) -o rtl_sim.out $(addprefix ../, $(TB_SRCS)) $(addprefix ../, $(RTL_SRCS))
	@echo "[SIM] Running top-level system simulation..."
	cd $(SIM_DIR) && $(VVP) rtl_sim.out

syn: firmware
	@mkdir -p $(SYN_DIR)
	@echo "[SYN] Synthesizing top-level design..."
	cd $(SYN_DIR) && $(YOSYS) -p "read_verilog $(addprefix -I../, $(INCLUDES)) $(addprefix ../, $(RTL_SRCS)); proc; flatten; synth -top cpu_aes_prng_top; write_verilog -noattr cpu_aes_prng_top_syn.v" > syn.log

gls_sim: syn firmware
	@mkdir -p $(SIM_DIR) $(GLS_DIR)
	@echo "[GLS] Running Gate-Level Simulation..."
	cd $(SIM_DIR) && $(IVERILOG) -DGATE_SIM -o gls_sim.out ../$(TB_SRCS) ../$(SYN_NETLIST) $(SIM_CELLS)
	cd $(SIM_DIR) && $(VVP) gls_sim.out
	mv $(SIM_DIR)/tb_cpu_aes_prng.vcd $(GLS_DIR)/ || true
	mv $(SIM_DIR)/gls_sim.out $(GLS_DIR)/ || true

clean:
	rm -rf $(SIM_DIR)/* $(SYN_DIR)/* $(GLS_DIR)/*
