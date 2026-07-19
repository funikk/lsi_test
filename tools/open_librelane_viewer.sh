#!/usr/bin/env bash
set -e

# Dynamically determine workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VIEWER="${1:-openroad}"
CONFIG_FILE="${2:-${WORKSPACE_ROOT}/librelane_designs/aes_prng_top/config.json}"
RUN_TAG="${3:-run_librelane}"

PDK_ROOT="${WORKSPACE_ROOT}/pdks"
LIBRELANE_DIR="${WORKSPACE_ROOT}/librelane"

if [ ! -d "$LIBRELANE_DIR" ]; then
    echo "Error: LibreLane directory not found at $LIBRELANE_DIR"
    exit 1
fi

# Ensure DISPLAY variable is set and disable X11 access control for Docker GUI
export DISPLAY="${DISPLAY:-:0}"
if command -v xhost &>/dev/null; then
    xhost + &>/dev/null || xhost +local:root &>/dev/null || true
fi

case "$VIEWER" in
    openroad|openinopenroad)
        FLOW="openinopenroad"
        echo "Opening design in OpenROAD GUI (DISPLAY=${DISPLAY})..."
        ;;
    klayout|openinklayout)
        FLOW="openinklayout"
        echo "Opening design in KLayout GUI (DISPLAY=${DISPLAY})..."
        ;;
    magic|openinmagic)
        FLOW="openinmagic"
        echo "Opening design in Magic GUI (DISPLAY=${DISPLAY})..."
        ;;
    *)
        echo "Usage: $0 [openroad|klayout|magic] [config.json] [run_tag]"
        echo "Example: $0 openroad"
        echo "Example: $0 klayout"
        echo "Example: $0 magic"
        exit 1
        ;;
esac

export PDK_ROOT="$PDK_ROOT"

cd "$LIBRELANE_DIR"
uv run python3 -m librelane \
    -m "$WORKSPACE_ROOT" \
    --dockerized \
    --pdk-root "$PDK_ROOT" \
    -p sky130A \
    -s sky130_fd_sc_hs \
    --run-tag "$RUN_TAG" \
    -f "$FLOW" \
    "$CONFIG_FILE"
