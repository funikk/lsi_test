# ==============================================================================
# Makefile for Synopsys Fusion Compiler Flow (VDRV_v1a)
# ==============================================================================

FC_BIN      ?= fc_shell
SCRIPT_DIR  = scripts
LOG_DIR     = logs
WORK_DIR    = work
REPORT_DIR  = reports
OUTPUT_DIR  = outputs

FC_FLAGS    = -64bit -f

.PHONY: all synth floorplan place cts route signoff clean gui help

all: run_all

help:
	@echo "=================================================================="
	@echo " Synopsys Fusion Compiler Flow Targets for VDRV_v1a"
	@echo "=================================================================="
	@echo " make all          : Run full RTL-to-GDSII flow (run_all.tcl)"
	@echo " make synth        : Run Logic Synthesis (00..04)"
	@echo " make floorplan    : Run Synthesis + Floorplan (00..05)"
	@echo " make place        : Run Placement & Optimization (00..06)"
	@echo " make cts          : Run Clock Tree Synthesis (00..07)"
	@echo " make route        : Run Routing & Post-Route Opt (00..08)"
	@echo " make signoff      : Run Signoff Reports & Deliverables Export (09)"
	@echo " make gui          : Launch Fusion Compiler GUI (fc_shell -gui)"
	@echo " make clean        : Clean work directory, reports, and logs"
	@echo "=================================================================="

$(LOG_DIR):
	mkdir -p $(LOG_DIR) $(WORK_DIR) $(REPORT_DIR) $(OUTPUT_DIR)

run_all: $(LOG_DIR)
	@echo "[FC] Running complete RTL-to-GDSII implementation flow..."
	$(FC_BIN) $(FC_FLAGS) $(SCRIPT_DIR)/run_all.tcl -output_log_file $(LOG_DIR)/fc_run_all.log

synth: $(LOG_DIR)
	@echo "[FC] Running Logic Synthesis..."
	$(FC_BIN) $(FC_FLAGS) $(SCRIPT_DIR)/00_common_setup.tcl \
	          -x "source $(SCRIPT_DIR)/01_lib_setup.tcl; source $(SCRIPT_DIR)/02_read_design.tcl; source $(SCRIPT_DIR)/03_constraints.tcl; source $(SCRIPT_DIR)/04_compile_synth.tcl; exit" \
	          -output_log_file $(LOG_DIR)/fc_synth.log

gui:
	$(FC_BIN) -gui &

clean:
	rm -rf $(LOG_DIR) $(WORK_DIR) $(REPORT_DIR) $(OUTPUT_DIR)
	rm -rf command.log filenames*.log default.svf *.view
