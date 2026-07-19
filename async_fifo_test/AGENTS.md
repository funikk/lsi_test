# Project 3: Asynchronous FIFO

This subproject implements a Clock Domain Crossing (CDC) Asynchronous FIFO buffer using Gray-code pointer synchronization and asynchronous clock timing constraints.

---

## 1. Directory Structure

```text
async_fifo_test/
├── Makefile
├── AGENTS.md                  # Async FIFO-specific reference (this file)
├── rtl/
│   └── async_fifo.v           # Asynchronous FIFO RTL
├── tb/
│   └── tb_async_fifo.v        # Testbench (with GATE_SIM support)
├── sim/                       # RTL Sim Output Directory
├── syn/                       # Synthesis Output Directory
│   ├── run_synth.ys           # Yosys synthesis script
│   ├── async_fifo.sdc         # CDC Timing constraints (SDC)
│   └── async_fifo_synth.v     # Synthesized Netlist (generated)
└── gls/                       # Gate-Level Sim Output Directory
```

---

## 2. Key Files

*   [async_fifo.v (RTL)](rtl/async_fifo.v): Dual-clock Gray-coded FIFO module.
*   [tb_async_fifo.v (TB)](tb/tb_async_fifo.v): Asymmetric dual-clock testbench (100 MHz write, 40 MHz read) with `GATE_SIM` macro support.
*   [run_synth.ys (Synthesis Script)](syn/run_synth.ys): Yosys script with parameter elaboration overrides (`ADDR_WIDTH=4`).
*   [async_fifo.sdc (Constraints)](syn/async_fifo.sdc): SDC constraints specifying asynchronous clock groups for CDC (ignoring cross-domain paths):
    ```tcl
    set_clock_groups -asynchronous -group [get_clocks wr_clk] -group [get_clocks rd_clk]
    ```

---

## 3. How to Run

Navigate to this directory (`async_fifo_test/`) and run:

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
