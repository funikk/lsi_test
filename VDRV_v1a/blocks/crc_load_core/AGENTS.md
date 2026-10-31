# CRC Load Core Sub-block (`blocks/crc_load_core`)

## Overview
This block contains the 128-bit parallel CRC / Galois-Field load generator core (`crc_load_core.v`) and its 32-bit polynomial division channel (`crc_channel.v`).

## Sub-block Commands
```bash
make unit_sim         # Run standalone unit testbench (tb_crc_load_core.v)
make lint             # Run Verilator lint check on crc_channel and crc_load_core
make presynth_check   # Run fast pre-synthesis AST and quality check
make syn              # Run Yosys synthesis check
```
