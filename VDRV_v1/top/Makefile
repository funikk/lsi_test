# Top-level Integration Makefile
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

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

.PHONY: all rtl_sim lint presynth_check syn clean

all: rtl_sim

lint:
	@mkdir -p $(SIM_DIR)
	@echo "[LINT] Checking top integration module"
	($(VERILATOR) --lint-only -Wall -Wno-fatal -Wno-DECLFILENAME -Wno-SYNCASYNCNET -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY -Wno-BLKSEQ -Wno-PINMISSING -Wno-MULTITOP -Wno-TIMESCALEMOD -Wno-GENUNNAMED $(INCLUDES) $(RTL_SRCS) || exit 0) 2>&1 | tee $(SIM_DIR)/lint.log

presynth_check:
	@mkdir -p $(SYN_DIR)
	@echo "[PRESYNTH] Running pre-synthesis check on top module"
	$(YOSYS) -p "read_verilog $(INCLUDES) $(RTL_SRCS); proc; check -assert" 2>&1 | tee $(SYN_DIR)/presynth_check.log

rtl_sim:
	@mkdir -p $(SIM_DIR)
	@echo "[SIM] Building system-level integration testbench..."
	( $(IVERILOG) -g2012 $(INCLUDES) -o $(SIM_DIR)/top_tb.vvp $(RTL_SRCS) $(TB_SRCS) && cd $(SIM_DIR) && $(VVP) top_tb.vvp ) 2>&1 | tee $(SIM_DIR)/rtl_sim.log

syn:
	@mkdir -p $(SYN_DIR)
	@echo "[SYN] Synthesizing full chip top design"
	$(YOSYS) -p "read_verilog $(INCLUDES) $(RTL_SRCS); proc; check -assert; write_verilog -noattr $(SYN_DIR)/top_gate.v" 2>&1 | tee $(SYN_DIR)/synth.log

clean:
	rm -rf $(SIM_DIR)/* $(SYN_DIR)/*
