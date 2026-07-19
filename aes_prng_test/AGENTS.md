# AES-128 PRNG Motif Circuit Project Reference

This directory (`aes_prng_test/`) contains an implementation of a self-stimulating AES-128 encryption core driven by pseudo-random number generators (PRNG). This design serves as a motif circuit for Place and Route (PnR) and IR-Drop analysis by providing a high-density, high-switching-activity workload with self-contained stimulus.

## Directory Structure
- `rtl/`: Contains the Verilog source files:
  - `aes_sbox.v`: Standard AES S-box lookup table.
  - `aes_core.v`: Iterative round-based AES-128 encryption core.
  - `lfsr_prng.v`: Four parallel 32-bit LFSRs shifting 32 bits per cycle to generate 128-bit pseudo-random sequences.
  - `aes_prng_top.v`: Top module connecting the PRNG and AES core.
- `tb/`: Contains the testbench.
- `sim/`: Output directory for RTL simulations.
- `syn/`: Output directory for synthesis. Contains:
  - `run_synth.ys`: Yosys synthesis script.
  - `aes_prng.sdc`: Synopsys Design Constraints (SDC) file for 100MHz clock.
- `gls/`: Output directory for Gate-Level Simulations.

## Design Details
* **lfsr_prng**: Generates 128-bit pseudorandom data/keys by running 32-step shifts of four independent 32-bit LFSRs in a single clock cycle. This guarantees high switching activity (close to 50% toggle rate) at the inputs.
* **aes_core**: An iterative AES-128 core. It instantiates 16 parallel S-boxes for `SubBytes` and 4 parallel S-boxes for key expansion (total 20 S-boxes) to maximize logic density and dynamic power.
* **aes_prng_top**: The top module. It starts a new 12-cycle AES encryption automatically every time the previous encryption finishes. This establishes a continuous loop of high-activity operations.

---

## How to Run

Navigate to this directory (`aes_prng_test/`) and run:

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
