# MAC Array Project Reference

This directory (`mac_array_test/`) contains an implementation of a parameterized 2D Systolic Array of Multiply-Accumulate (MAC) units. This design serves as a testbed for Place and Route (PnR) and IR-Drop analysis by providing a high-density, high-switching-activity workload.

## Directory Structure
- `rtl/`: Contains the Verilog source files for the MAC unit and the MAC array.
- `tb/`: Contains the testbench.
- `sim/`: Output directory for RTL simulations.
- `syn/`: Output directory for synthesis.
- `gls/`: Output directory for Gate-Level Simulations.

## Design Details
* **mac_unit**: A single Multiply-Accumulate cell with registered inputs and outputs.
* **mac_array**: A 2D grid of MAC units. Data `A` flows horizontally, `B` flows vertically, and partial sums `C` flow vertically downwards.

This motif circuit is designed to stress the power grid when all units are active simultaneously.
