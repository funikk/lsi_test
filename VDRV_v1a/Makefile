# Multi-Developer Modular Dispatch Makefile for VDRV_v1a

BLOCKS_DIR := blocks
BLOCK_DIRS := $(wildcard $(BLOCKS_DIR)/*)
BLOCK_NAMES := $(notdir $(BLOCK_DIRS))
UNIT_SIM_TARGETS := $(addprefix unit_sim_,$(BLOCK_NAMES))
TOP_DIR    := top
FW_DIR     := firmware

.PHONY: all help firmware unit_sim $(UNIT_SIM_TARGETS) block_sim block_syn top_sim rtl_sim top_syn syn lint presynth_check pnr pnr_qor clean

all: firmware unit_sim top_sim

help:
	@echo "Multi-Developer Project Automation Makefile (VDRV_v1a)"
	@echo "---------------------------------------------------"
	@echo "make firmware           : Compile RISC-V C firmware"
	@echo "make unit_sim           : Run unit simulations for all blocks sequentially"
	@echo "make -j unit_sim        : Run unit simulations for all blocks in PARALLEL (Multi-core)"
	@echo "make BLOCK=<name> block_sim : Run unit simulation for target block (e.g. BLOCK=template_block)"
	@echo "make BLOCK=<name> block_syn : Run Out-of-Context synthesis for target block"
	@echo "make top_sim (rtl_sim)  : Run top-level system integration simulation"
	@echo "make top_syn (syn)      : Run full-chip synthesis"
	@echo "make lint               : Run Verilator lint across all blocks and top"
	@echo "make presynth_check     : Run fast Yosys pre-synthesis checks across all modules"
	@echo "make pnr                : Run PnR flow using LibreLane"
	@echo "make pnr_qor            : Report PnR QoR & runtime summary"
	@echo "make clean              : Clean temporary files in firmware, all blocks and top"

firmware:
	@if [ -d $(FW_DIR) ]; then $(MAKE) -C $(FW_DIR); fi

unit_sim: $(UNIT_SIM_TARGETS)

$(UNIT_SIM_TARGETS): unit_sim_%:
	@echo "==================================================="
	@echo "[RUNNING UNIT SIM] Sub-block: $*"
	@echo "==================================================="
	$(MAKE) -C $(BLOCKS_DIR)/$* unit_sim

block_sim:
ifndef BLOCK
	$(error BLOCK is not defined. Usage: make BLOCK=template_block block_sim)
endif
	@echo "[TARGETED BLOCK SIM] Block: $(BLOCK)"
	$(MAKE) -C $(BLOCKS_DIR)/$(BLOCK) unit_sim

block_syn:
ifndef BLOCK
	$(error BLOCK is not defined. Usage: make BLOCK=template_block block_syn)
endif
	@echo "[TARGETED BLOCK SYNTHESIS] Block: $(BLOCK)"
	$(MAKE) -C $(BLOCKS_DIR)/$(BLOCK) syn

top_sim rtl_sim: firmware
	@echo "==================================================="
	@echo "[RUNNING SYSTEM INTEGRATION SIMULATION]"
	@echo "==================================================="
	$(MAKE) -C $(TOP_DIR) rtl_sim

top_syn syn: firmware
	@echo "==================================================="
	@echo "[RUNNING FULL CHIP SYNTHESIS]"
	@echo "==================================================="
	$(MAKE) -C $(TOP_DIR) syn

lint:
	@for dir in $(BLOCK_DIRS) $(TOP_DIR); do \
		$(MAKE) -C $$dir lint || exit 1; \
	done

presynth_check: firmware
	@for dir in $(BLOCK_DIRS) $(TOP_DIR); do \
		$(MAKE) -C $$dir presynth_check || exit 1; \
	done

PNR_REMOTE ?= $(PNR_REMOTE_HOST)

pnr:
	nix develop ../librelane --command python3 ../tools/run_pnr.py VDRV_v1a_core --hide-progress-bar $(if $(PNR_REMOTE),--remote $(PNR_REMOTE))

pnr_qor:
	mkdir -p docs/backend
	../tools/report_qor_phases.py ../librelane_designs/VDRV_v1a_core/runs/run_100MHz > docs/backend/pnr_qor_report.md

clean:
	@if [ -d $(FW_DIR) ]; then $(MAKE) -C $(FW_DIR) clean; fi
	@for dir in $(BLOCK_DIRS) $(TOP_DIR); do \
		$(MAKE) -C $$dir clean; \
	done

