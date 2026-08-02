# PicoRV32 RISC-V CPU Core Sub-block (`blocks/picorv32_cpu`)

## Overview
This block contains the PicoRV32 32-bit RISC-V CPU core (`picorv32.v`).

## Sub-block Commands
```bash
make unit_sim    # Build and run standalone unit testbench (Memory fetch handshake)
make lint        # Run Verilator lint check on picorv32
make syn         # Run Yosys out-of-context synthesis check
make clean       # Clean simulation and synthesis build artifacts
```
