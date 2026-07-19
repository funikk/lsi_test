# Project 2: Synchronous FIFO

This subproject implements a parameterizable Synchronous FIFO buffer to study logic synthesis mapping (registers vs. memory) and timing constraints.

---

## 1. Directory Structure

```text
fifo_test/
├── Makefile
├── AGENTS.md                  # Sync FIFO-specific reference (this file)
├── rtl/
│   └── sync_fifo.v            # Synchronous FIFO RTL
├── tb/
│   └── tb_sync_fifo.v         # Testbench (with GATE_SIM support)
├── sim/                       # RTL Sim Output Directory
├── syn/                       # Synthesis Output Directory
│   ├── run_synth.ys           # Yosys synthesis script
│   ├── sync_fifo.sdc          # Timing constraints (SDC)
│   └── sync_fifo_synth.v      # Synthesized Netlist (generated)
└── gls/                       # Gate-Level Sim Output Directory
```

---

## 2. Key Files

*   [sync_fifo.v (RTL)](rtl/sync_fifo.v): Parameterizable dual-port array-based FIFO.
*   [tb_sync_fifo.v (TB)](tb/tb_sync_fifo.v): Multi-purpose testbench supporting both RTL and gate simulation via `GATE_SIM` compiler macro.
*   [run_synth.ys (Synthesis Script)](syn/run_synth.ys): Yosys script with parameter elaboration overrides (`DEPTH=8`).
*   [sync_fifo.sdc (Constraints)](syn/sync_fifo.sdc): Timing and physical constraints (100 MHz target, I/O delays, max fanout/transition) ready for physical design tools.

---

## 3. How to Run

Navigate to this directory (`fifo_test/`) and run:

```bash
# Run lint check
make lint

# Run RTL simulation
make rtl_sim

# Run synthesis
make syn

# Run gate-level simulation (GLS)
make gls_sim

# Run all verification phases
make all
```
