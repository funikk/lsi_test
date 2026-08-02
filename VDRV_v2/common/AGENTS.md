# Shared Common Assets (`common/`)

This directory contains shared constants, header files, interface packages, and global scripts shared across sub-blocks and top integration.

## Rules
- Modifying files in `common/` impacts multiple sub-blocks. Changes must be coordinated via `system_architect` or `project_manager`.
- Header files must use standard Verilog include guards (`ifndef GLOBAL_DEFINES_VH` ... `endif`).
