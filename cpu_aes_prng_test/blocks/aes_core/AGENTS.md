# AES-128 Encryption Core Sub-block (`blocks/aes_core`)

## Overview
This block contains the iterative AES-128 hardware core (`aes_core.v`) and its parallel S-box lookup module (`aes_sbox.v`).

## Module Interfaces
- `aes_core`: Iterative 10-round AES-128 encryption core. Single 128-bit block is encrypted in 10 clock cycles.

## Sub-block Commands
```bash
make unit_sim    # Build and run standalone unit testbench (FIPS-197 test vector)
make lint        # Run Verilator lint check on aes_core & aes_sbox
make syn         # Run Yosys out-of-context synthesis check
make clean       # Clean simulation and synthesis build artifacts
```
