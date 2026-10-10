# Load Sequencer Sub-Block (`blocks/load_sequencer`)

Load Sequencer generates autonomous, cycle-accurate multi-step load profiles, power domain requests, and synchronization pulses for VDRV_v3.

## Directory Layout
- `rtl/`: Synthesizable Verilog-2005 RTL (`load_sequencer.v`).
- `tb/`: Unit testbench (`tb_load_sequencer.v`) with self-checking assertions.
- `sim/`: Simulation artifacts, waveforms (`.vcd`), and logs.
- `syn/`: Synthesis logs and netlists.
- `filelist.f`: RTL source file list (`./rtl/load_sequencer.v`).
- `Makefile`: Standalone sub-block verification flow.

## Verification Commands
- `make lint`: Verilator static analysis (`verilator -Wall`).
- `make presynth_check`: Fast syntax and assertion pre-synthesis check with Yosys.
- `make unit_sim`: Run standalone Icarus Verilog testbench (`TEST PASSED`).
- `make syn`: Run out-of-context logic synthesis with Yosys.
