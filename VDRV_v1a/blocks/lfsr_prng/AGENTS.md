# 128-bit LFSR PRNG Sub-block (`blocks/lfsr_prng`)

## Overview
This block contains the 128-bit LFSR Pseudo-Random Number Generator (`lfsr_prng_ctrl.v`), consisting of four parallel 32-bit Galois/Fibonacci LFSR units.

## Sub-block Commands
```bash
make unit_sim    # Build and run standalone unit testbench (Seed load & LFSR evolution)
make lint        # Run Verilator lint check on lfsr_prng_ctrl
make syn         # Run Yosys out-of-context synthesis check
make clean       # Clean simulation and synthesis build artifacts
```
