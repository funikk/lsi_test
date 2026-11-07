# ==============================================================================
# Makefile for Synopsys VCS Simulation & Verdi Debugging (VDRV_v1a)
# Supports RTL Simulation and Gate-Level Simulation (GLS)
# ==============================================================================

SIMV            = ./simv
GLS_SIMV        = ./simv_gls
FILELIST        = vcs_filelist.f
GLS_FILELIST    = vcs_gls_filelist.f
TOP_TB          = tb_VDRV_v1a_top
HEX_PATH        ?= ../firmware/firmware.hex
WAVE_FORMAT     ?= FSDB  # FSDB, VCD, or NONE

# Gate-Level Simulation (GLS) Parameters
GLS_NETLIST     ?= ../fc/outputs/VDRV_v1a_core.v
CELL_LIB        ?= # e.g. /path/to/sky130_fd_sc_hd.v or /usr/share/yosys/simlib.v
TIMING          ?= 0 # 0: Zero-delay functional GLS, 1: SDF timing simulation
SDF_FILE        ?= ../fc/outputs/VDRV_v1a_core.sdf
SDF_TYPE        ?= typ # min, typ, or max
XPROP           ?= 0 # 1: Enable X-Propagation analysis (-xprop=tmerge)

# Common VCS Flags
VCS_COMMON_FLAGS = -full64 \
                   -sverilog \
                   +v2k \
                   -timescale=1ns/1ps \
                   -debug_access+all \
                   -kdb \
                   -lca \
                   -top $(TOP_TB) \
                   +define+FIRMWARE_HEX=\"$(HEX_PATH)\"

ifeq ($(WAVE_FORMAT), FSDB)
    VCS_COMMON_FLAGS += +define+DUMP_FSDB
else ifeq ($(WAVE_FORMAT), VCD)
    VCS_COMMON_FLAGS += +define+DUMP_VCD
else
    VCS_COMMON_FLAGS += +define+NO_DUMP
endif

ifeq ($(XPROP), 1)
    VCS_COMMON_FLAGS += -xprop=tmerge
endif

# RTL Simulation Flags
VCS_FLAGS       = $(VCS_COMMON_FLAGS) \
                  -f $(FILELIST) \
                  -l compile.log

# GLS Simulation Flags
VCS_GLS_FLAGS   = $(VCS_COMMON_FLAGS) \
                  -f $(GLS_FILELIST) \
                  $(GLS_NETLIST) \
                  +define+GATE_SIM \
                  -l gls_compile.log

# Attach Cell Libraries if specified
ifneq ($(strip $(CELL_LIB)),)
    VCS_GLS_FLAGS += $(foreach lib,$(CELL_LIB),-v $(lib))
endif

# Timing vs Zero-delay mode for GLS
ifeq ($(TIMING), 1)
    VCS_GLS_FLAGS += -negdelay \
                     +neg_tchk \
                     +sdfverbose \
                     -sdf $(SDF_TYPE):$(TOP_TB).u_top.u_core:\"$(SDF_FILE)\" \
                     +define+SDF_FILE=\"$(SDF_FILE)\"
else
    VCS_GLS_FLAGS += +nospecify \
                     +notimingcheck \
                     +delay_mode_zero
endif

# Optional coverage flags
ifdef COV
    VCS_FLAGS     += -cm line+cond+fsm+tgl+branch -cm_dir simv.vdb
    VCS_GLS_FLAGS += -cm line+cond+fsm+tgl+branch -cm_dir simv_gls.vdb
    SIMV_FLAGS    += -cm line+cond+fsm+tgl+branch -cm_dir simv.vdb
    GLS_SIM_FLAGS += -cm line+cond+fsm+tgl+branch -cm_dir simv_gls.vdb
endif

.PHONY: all comp run sim verdi gls_comp gls_run gls_sim gls_verdi clean help

all: sim

help:
	@echo "=================================================================="
	@echo " Synopsys VCS Simulation Targets for VDRV_v1a"
	@echo "=================================================================="
	@echo " RTL Simulation:"
	@echo "   make comp         : Compile RTL & TB into simv using VCS"
	@echo "   make run          : Execute RTL simulation with simv"
	@echo "   make sim          : Compile and run RTL simulation (default)"
	@echo "   make verdi        : Open Verdi GUI for RTL waveform (FSDB)"
	@echo ""
	@echo " Gate-Level Simulation (GLS):"
	@echo "   make gls_comp     : Compile gate-level netlist & TB into simv_gls"
	@echo "   make gls_run      : Execute gate-level simulation with simv_gls"
	@echo "   make gls_sim      : Compile and run GLS (Zero-delay or SDF)"
	@echo "   make gls_verdi    : Open Verdi GUI for GLS waveform"
	@echo ""
	@echo " General:"
	@echo "   make clean        : Remove compiled binaries, logs, and waves"
	@echo ""
	@echo " Options:"
	@echo "   WAVE_FORMAT=FSDB|VCD|NONE  (Default: FSDB)"
	@echo "   COV=1                      (Enable code coverage instrumentation)"
	@echo "   HEX_PATH=<path>            (Path to firmware hex file)"
	@echo "   GLS_NETLIST=<path>         (Path to gate netlist, default: ../fc/outputs/VDRV_v1a_core.v)"
	@echo "   CELL_LIB=<path>            (Path to standard cell Verilog model)"
	@echo "   TIMING=0|1                 (0: Zero-delay functional, 1: SDF timing, default: 0)"
	@echo "   SDF_FILE=<path>            (Path to SDF file when TIMING=1)"
	@echo "   SDF_TYPE=min|typ|max       (SDF corner, default: typ)"
	@echo "   XPROP=0|1                  (Enable X-propagation modeling, default: 0)"
	@echo "=================================================================="

# Check firmware helper
check_firmware:
	@if [ ! -f "$(HEX_PATH)" ]; then \
		echo "[INFO] Firmware hex not found. Building firmware..."; \
		$(MAKE) -C ../firmware hex; \
	fi

# ------------------------------------------------------------------------------
# RTL Simulation Targets
# ------------------------------------------------------------------------------
comp $(SIMV): $(FILELIST) check_firmware
	@echo "[VCS] Compiling RTL design with VCS..."
	vcs $(VCS_FLAGS)

run: $(SIMV)
	@echo "[VCS] Running RTL simulation..."
	$(SIMV) $(SIMV_FLAGS) -l sim.log

sim: comp run

verdi:
	@echo "[VERDI] Launching Verdi GUI for RTL..."
	verdi -dbdir $(SIMV).daidir -ssf $(TOP_TB).fsdb &

# ------------------------------------------------------------------------------
# Gate-Level Simulation (GLS) Targets
# ------------------------------------------------------------------------------
gls_comp $(GLS_SIMV): $(GLS_FILELIST) check_firmware
	@echo "[VCS] Checking Gate-level netlist: $(GLS_NETLIST)"
	@if [ ! -f "$(GLS_NETLIST)" ]; then \
		echo "[ERROR] Gate-level netlist not found: $(GLS_NETLIST)"; \
		echo "        Please run Fusion Compiler ('make -C ../fc all' or 'make -C ../fc synth')"; \
		echo "        or specify an alternative netlist via GLS_NETLIST=<path>."; \
		exit 1; \
	fi
	@echo "[VCS] Compiling Gate-Level design with VCS (TIMING=$(TIMING))..."
	vcs -o $(GLS_SIMV) $(VCS_GLS_FLAGS)

gls_run: $(GLS_SIMV)
	@echo "[VCS] Running Gate-Level simulation..."
	$(GLS_SIMV) $(GLS_SIM_FLAGS) -l gls_sim.log

gls_sim: gls_comp gls_run

gls_verdi:
	@echo "[VERDI] Launching Verdi GUI for GLS..."
	verdi -dbdir $(GLS_SIMV).daidir -ssf $(TOP_TB).fsdb &

# Clean Target
clean:
	rm -rf $(SIMV) $(SIMV).daidir $(GLS_SIMV) $(GLS_SIMV).daidir
	rm -rf csrc simv.vdb simv_gls.vdb ucli.key vc_hdrs.h
	rm -rf compile.log sim.log gls_compile.log gls_sim.log
	rm -rf novas.* verdiLog *.fsdb *.vcd tr_debug.log
