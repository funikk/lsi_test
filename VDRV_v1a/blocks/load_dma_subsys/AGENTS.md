# Load DMA Subsystem Sub-block (`blocks/load_dma_subsys`)

## Overview
This block contains the `load_dma_subsys` module, integrating the MAC load core, CRC load core, 128-bit LFSR PRNG, and DMA transfer engine. It mediates both software MMIO continuous/finite block loading and cycle-accurate hardware-direct load sequencer control.

## Sub-block Commands
```bash
make unit_sim        # Build and run comprehensive unit testbench (Seed/Config, DMA MAC/CRC/XOR, SW finite mode, HW-direct stepping)
make lint            # Run Verilator lint check
make presynth_check  # Run pre-synthesis quality check (proc; check -assert)
make syn             # Run Yosys out-of-context synthesis
make clean           # Clean simulation and synthesis build artifacts
```
