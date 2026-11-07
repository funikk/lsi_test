#!/usr/bin/env bash
# ==============================================================================
# Environment Configuration for Fusion Compiler (VDRV_v1a)
# Source this file before launching fc_shell or make commands:
#   source fc_env.sh
# ==============================================================================

# Target Design Top
export DESIGN_NAME="VDRV_v1a_core"

# Number of parallel CPU threads for Fusion Compiler
export FC_NUM_CORES="${FC_NUM_CORES:-8}"

# Target Technology / PDK Configuration
# Set FC_PDK_ROOT to point to your Foundry PDK installation (e.g., TSMC, SAED32, Sky130, etc.)
export FC_PDK_ROOT="${FC_PDK_ROOT:-/opt/pdk}"
export FC_TECH_NAME="${FC_TECH_NAME:-generic_or_sky130}"

# Synopsys Reference Libraries (NDM format for Fusion Compiler)
# Example: export FC_NDM_LIBS="/path/to/tech.ndm /path/to/stdcell.ndm /path/to/sram.ndm"
export FC_NDM_LIBS="${FC_NDM_LIBS:-}"

# TLUPlus Parasitic Extraction Models (Min / Max / Typical)
export FC_TECH_FILE="${FC_TECH_FILE:-}"
export FC_TLUPLUS_MAX="${FC_TLUPLUS_MAX:-}"
export FC_TLUPLUS_MIN="${FC_TLUPLUS_MIN:-}"
export FC_MAP_FILE="${FC_MAP_FILE:-}"

echo "[FC_ENV] Environment configured for design: ${DESIGN_NAME}"
echo "[FC_ENV] PDK Root: ${FC_PDK_ROOT} (Tech: ${FC_TECH_NAME})"
echo "[FC_ENV] CPU Cores: ${FC_NUM_CORES}"
