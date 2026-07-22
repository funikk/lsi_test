BLOCK_NAME := picorv32_cpu

IVERILOG  := iverilog
VVP       := vvp
VERILATOR := verilator
YOSYS     := yosys

SIM_DIR := sim
SYN_DIR := syn
RTL_DIR := rtl
TB_DIR  := tb

RTL_SRCS := rtl/picorv32.v
TB_SRCS  := tb/tb_picorv32.v
INCLUDES := -Irtl

.PHONY: all unit_sim lint presynth_check syn clean

all: unit_sim

lint:
	@echo "[LINT] Checking block: $(BLOCK_NAME)"
	$(VERILATOR) --lint-only -Wall -Werror-MULTIDRIVEN -Wno-fatal $(INCLUDES) $(RTL_SRCS)

presynth_check: syn

unit_sim:
	@mkdir -p $(SIM_DIR)
	@echo "[SIM] Building unit testbench for $(BLOCK_NAME)..."
	$(IVERILOG) -g2012 $(INCLUDES) -o $(SIM_DIR)/$(BLOCK_NAME)_tb.vvp $(RTL_SRCS) $(TB_SRCS)
	@echo "[SIM] Running unit testbench for $(BLOCK_NAME)..."
	cd $(SIM_DIR) && $(VVP) $(BLOCK_NAME)_tb.vvp

syn:
	@mkdir -p $(SYN_DIR)
	@echo "[SYN] Synthesizing block: $(BLOCK_NAME)"
	$(YOSYS) -p "read_verilog $(INCLUDES) $(RTL_SRCS); proc; check -assert; write_verilog -noattr $(SYN_DIR)/$(BLOCK_NAME)_gate.v" > $(SYN_DIR)/syn.log

clean:
	rm -rf $(SIM_DIR)/* $(SYN_DIR)/*
