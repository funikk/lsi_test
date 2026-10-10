# Sub-Block Template (`blocks/template_block`)

Copy this directory or use `add_sub_block.sh` when creating a new sub-block sandbox for a new block designer or subagent.

## Directory Layout
- `rtl/`: Pure synthesizable block RTL.
- `tb/`: Unit testbench for block-level simulation.
- `sim/`: Output folder for simulation dumps (`.vvp`, `.vcd`, logs).
- `syn/`: Output folder for Out-of-Context (OOC) block synthesis.
- `filelist.f`: Relative list of RTL files used by this block.
- `Makefile`: Standalone Makefile for unit testing.
