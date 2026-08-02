# AES-DMA Subsystem Sub-block (`blocks/aes_dma_subsys`)

## Overview
This block contains the AES-128 / LFSR PRNG DMA subsystem (`aes_dma_subsys.v`), providing MMIO register control, SRAM DMA access, and high-load PRNG stress modes.

## Module Dependencies
- `aes_core.v` (`blocks/aes_core`)
- `aes_sbox.v` (`blocks/aes_core`)
- `lfsr_prng_ctrl.v` (`blocks/lfsr_prng`)

## Sub-block Commands
```bash
make unit_sim    # Build and run standalone unit testbench (MMIO register read/write & DMA)
make lint        # Run Verilator lint check on subsystem and dependencies
make syn         # Run Yosys out-of-context synthesis check
make clean       # Clean simulation and synthesis build artifacts
```
