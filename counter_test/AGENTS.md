# Project 1: Simple 8-bit Counter

This subproject implements a basic 8-bit binary counter to verify the simulator and linter toolchain setup.

---

## 1. Directory Structure

```text
counter_test/
├── Makefile
├── AGENTS.md                  # Counter-specific reference (this file)
├── rtl/
│   └── counter.v              # 8-bit Counter RTL
├── tb/
│   └── tb_counter.v           # Testbench
├── sim/                       # RTL Sim Output Directory
├── syn/                       # Synthesis Output Directory
│   ├── run_synth.ys           # Yosys synthesis script
│   └── counter_synth.v        # Synthesized Netlist (generated)
└── gls/                       # Gate-Level Sim Output Directory
```

---

## 2. Key Files

*   [counter.v (RTL)](rtl/counter.v): 8-bit counter module.
*   [tb_counter.v (TB)](tb/tb_counter.v): Testbench verifying the counter's behavior and dumping VCD waves.
*   [run_synth.ys (Synthesis Script)](syn/run_synth.ys): Yosys script mapping the counter module to gate cells.

---

## 3. How to Run

Navigate to this directory (`counter_test/`) and run:

```bash
# Run lint check
make lint

# Run pre-synthesis fast check (0.7s)
make presynth_check

# Run RTL simulation
make rtl_sim

# Run synthesis
make syn

# Run gate-level simulation (GLS)
make gls_sim

# Run all verification phases
make all
```
