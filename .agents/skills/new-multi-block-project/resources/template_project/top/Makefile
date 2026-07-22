# Top-level Integration Makefile
COMMON_DIR := ../common

IVERILOG  := iverilog
VVP       := vvp
VERILATOR := verilator
YOSYS     := yosys

SIM_DIR := sim
SYN_DIR := syn
RTL_DIR := rtl
TB_DIR  := tb

RTL_SRCS := $(shell grep -v '^\s*#' filelist.f | grep -v '^\s*$$')
TB_SRCS  := $(wildcard $(TB_DIR)/*.v)
INCLUDES := -I$(COMMON_DIR)/rtl -I$(RTL_DIR) $(addprefix -I, $(wildcard ../blocks/*/rtl))

.PHONY: all rtl_sim lint syn clean

all: rtl_sim

lint:
	@echo "[LINT] Checking top integration module"
	$(VERILATOR) --lint-only -Wall $(INCLUDES) $(RTL_SRCS)

rtl_sim:
	@mkdir -p $(SIM_DIR)
	@echo "[SIM] Building system-level integration testbench..."
	$(IVERILOG) -g2012 $(INCLUDES) -o $(SIM_DIR)/top_tb.vvp $(RTL_SRCS) $(TB_SRCS)
	@echo "[SIM] Running system-level integration testbench..."
	cd $(SIM_DIR) && $(VVP) top_tb.vvp

syn:
	@mkdir -p $(SYN_DIR)
	@echo "[SYN] Synthesizing full chip top design"
	$(YOSYS) -p "read_verilog $(INCLUDES) $(RTL_SRCS); proc; check -assert; write_verilog -noattr $(SYN_DIR)/top_gate.v" > $(SYN_DIR)/syn.log

clean:
	rm -rf $(SIM_DIR)/* $(SYN_DIR)/*
