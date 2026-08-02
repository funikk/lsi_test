# Sub-Block Standalone Makefile Template
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

BLOCK_NAME := template_block
COMMON_DIR := ../../common

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
INCLUDES := -I$(COMMON_DIR)/rtl -I$(RTL_DIR)

.PHONY: all unit_sim lint presynth_check syn clean

all: unit_sim

lint:
	@mkdir -p $(SIM_DIR)
	@echo "[LINT] Checking block: $(BLOCK_NAME)"
	$(VERILATOR) --lint-only -Wall $(INCLUDES) $(RTL_SRCS) 2>&1 | tee $(SIM_DIR)/lint.log

presynth_check:
	@mkdir -p $(SYN_DIR)
	@echo "[PRESYNTH] Running pre-synthesis check on block: $(BLOCK_NAME)"
	$(YOSYS) -p "read_verilog $(INCLUDES) $(RTL_SRCS); proc; check -assert" 2>&1 | tee $(SYN_DIR)/presynth_check.log

unit_sim:
	@mkdir -p $(SIM_DIR)
	@echo "[SIM] Building unit testbench for $(BLOCK_NAME)..."
	( $(IVERILOG) -g2012 $(INCLUDES) -o $(SIM_DIR)/$(BLOCK_NAME)_tb.vvp $(RTL_SRCS) $(TB_SRCS) && cd $(SIM_DIR) && $(VVP) $(BLOCK_NAME)_tb.vvp ) 2>&1 | tee $(SIM_DIR)/unit_sim.log

syn:
	@mkdir -p $(SYN_DIR)
	@echo "[SYN] Synthesizing block: $(BLOCK_NAME)"
	$(YOSYS) -p "read_verilog $(INCLUDES) $(RTL_SRCS); proc; check -assert; write_verilog -noattr $(SYN_DIR)/$(BLOCK_NAME)_gate.v" 2>&1 | tee $(SYN_DIR)/synth.log

clean:
	rm -rf $(SIM_DIR)/* $(SYN_DIR)/*
