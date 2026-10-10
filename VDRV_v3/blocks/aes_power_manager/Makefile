SHELL := /bin/bash
SHELLFLAGS := -o pipefail -c

IVERILOG := iverilog
VVP := vvp
VERILATOR := verilator
YOSYS := yosys

RTL_SRCS := rtl/aes_power_manager.v rtl/aes_isolation.v
TB_SRCS := tb/tb_aes_power_manager.v

.PHONY: all unit_sim lint presynth_check syn clean

all: unit_sim

unit_sim:
	@mkdir -p sim
	$(IVERILOG) -g2012 -DPOWER_AWARE_SIM -o sim/aes_power_manager_tb.vvp $(RTL_SRCS) $(TB_SRCS)
	cd sim && $(VVP) aes_power_manager_tb.vvp

lint:
	@mkdir -p sim
	$(VERILATOR) --lint-only -Wall -Wno-fatal $(RTL_SRCS)

presynth_check:
	@mkdir -p syn
	$(YOSYS) -p "read_verilog $(RTL_SRCS); proc; check -assert"

syn:
	@mkdir -p syn
	$(YOSYS) -p "read_verilog $(RTL_SRCS); proc; check -assert; write_verilog -noattr syn/aes_power_manager_gate.v"

clean:
	rm -rf sim/* syn/*
