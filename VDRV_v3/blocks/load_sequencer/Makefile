# Sub-Block Standalone Makefile for load_sequencer
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

BLOCK := load_sequencer

SIM_DIR := sim
SYN_DIR := syn

.PHONY: all unit_sim lint presynth_check syn clean

all: unit_sim

unit_sim:
	@mkdir -p $(SIM_DIR)
	( iverilog -o $(SIM_DIR)/sim.vvp -f filelist.f ./tb/tb_load_sequencer.v && vvp $(SIM_DIR)/sim.vvp ) 2>&1 | tee $(SIM_DIR)/unit_sim.log

lint:
	@mkdir -p $(SIM_DIR)
	verilator --lint-only -Wall -Wno-DECLFILENAME -f filelist.f 2>&1 | tee $(SIM_DIR)/lint.log

presynth_check:
	@mkdir -p $(SYN_DIR)
	yosys -p "read_verilog -sv ./rtl/*.v; proc; check -assert" 2>&1 | tee $(SYN_DIR)/presynth_check.log

syn:
	@mkdir -p $(SYN_DIR)
	yosys -p "read_verilog -sv ./rtl/*.v; synth -top $(BLOCK)" 2>&1 | tee $(SYN_DIR)/synth.log

clean:
	rm -rf $(SIM_DIR)/* $(SYN_DIR)/* sim.vvp *.vcd syn.log
