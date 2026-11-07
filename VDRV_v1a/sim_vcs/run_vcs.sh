#!/usr/bin/env bash
# ==============================================================================
# Script to run VCS Simulation & Verdi debugging for VDRV_v1a
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

MODE="${1:-sim}"
WAVE="${2:-FSDB}"

case "${MODE}" in
    comp)
        make comp WAVE_FORMAT="${WAVE}"
        ;;
    run)
        make run
        ;;
    sim)
        make sim WAVE_FORMAT="${WAVE}"
        ;;
    verdi)
        make verdi
        ;;
    gls_comp)
        make gls_comp WAVE_FORMAT="${WAVE}"
        ;;
    gls_run)
        make gls_run
        ;;
    gls_sim|gls)
        make gls_sim WAVE_FORMAT="${WAVE}"
        ;;
    gls_verdi)
        make gls_verdi
        ;;
    clean)
        make clean
        ;;
    *)
        echo "Usage: $0 [sim|comp|run|verdi|gls_sim|gls_comp|gls_run|gls_verdi|clean] [FSDB|VCD|NONE]"
        exit 1
        ;;
esac
