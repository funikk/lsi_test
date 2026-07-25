#!/usr/bin/env bash
set -e

# Dynamically determine workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure DISPLAY variable is set for GUI
export DISPLAY="${DISPLAY:-:0}"
if command -v xhost &>/dev/null; then
    xhost + &>/dev/null || xhost +local:root &>/dev/null || true
fi

python3 "${SCRIPT_DIR}/open_viewer.py" "$@"
