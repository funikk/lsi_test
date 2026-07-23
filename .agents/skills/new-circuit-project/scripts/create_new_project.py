#!/usr/bin/env python3
import os
import sys
import argparse
from pathlib import Path

def create_project(project_name: str, force: bool = False):
    # Determine project root (assumed to be current directory or relative to script)
    root_dir = Path.cwd()
    project_dir = root_dir / project_name

    if project_dir.exists() and not force:
        print(f"Error: Project directory '{project_name}' already exists. Use --force to overwrite.", file=sys.stderr)
        sys.exit(1)

    # Subdirectories to create
    subdirs = ["rtl", "tb", "sim", "syn", "gls", "docs"]
    for sd in subdirs:
        (project_dir / sd).mkdir(parents=True, exist_ok=True)

    # 0. Specification Template: <name>/docs/spec.md
    spec_content = f"""# Module Specification: {project_name}

## 1. Overview
Describe the purpose and high-level functionality of `{project_name}`.

## 2. Interface Signals
| Port Name | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | Clock signal |
| `rst_n` | Input | 1 | Active-Low Reset |
| `in_valid` | Input | 1 | Input Data Valid |
| `in_data` | Input | 8 | Input Data Byte |
| `out_valid` | Output | 1 | Output Data Valid |
| `out_data` | Output | 8 | Output Data Byte |

## 3. Architecture & Logic Details
Detail internal pipeline, state machine, or sub-modules here.
"""
    (project_dir / "docs" / "spec.md").write_text(spec_content)

    # 1. RTL Template: <name>/rtl/<name>.v
    rtl_content = f"""// {project_name}.v - Synthesizable Top Module for {project_name}
module {project_name} (
    input  wire clk,
    input  wire rst_n,
    input  wire in_valid,
    input  wire [7:0] in_data,
    output reg  out_valid,
    output reg  [7:0] out_data
);

    always @(posedge clk) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_data  <= 8'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                out_data <= in_data + 1'b1;
            end
        end
    end

endmodule
"""
    (project_dir / "rtl" / f"{project_name}.v").write_text(rtl_content)

    # 2. Testbench Template: <name>/tb/tb_<name>.v
    tb_content = f"""// tb_{project_name}.v - Testbench for {project_name}
`timescale 1ns / 1ps

module tb_{project_name};

    reg clk;
    reg rst_n;
    reg in_valid;
    reg [7:0] in_data;
    wire out_valid;
    wire [7:0] out_data;

    // Clock generation (100MHz = 10ns period)
    always #5 clk = ~clk;

`ifdef GATE_SIM
    {project_name} u_dut (
`else
    {project_name} u_dut (
`endif
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(out_valid),
        .out_data(out_data)
    );

    initial begin
        $dumpfile("tb_{project_name}.vcd");
        $dumpvars(0, tb_{project_name});

        clk = 0;
        rst_n = 0;
        in_valid = 0;
        in_data = 8'h0;

        #20;
        rst_n = 1;
        #10;

        // Stimulus
        in_valid = 1;
        in_data = 8'hA5;
        #10;
        in_valid = 0;
        #20;

        $display("[TB SUCCESS] Simulation completed for {project_name}.");
        $finish;
    end

endmodule
"""
    (project_dir / "tb" / f"tb_{project_name}.v").write_text(tb_content)

    # 3. Yosys presynth_check.ys: <name>/syn/presynth_check.ys
    presynth_content = f"""# Pre-synthesis AST check
read_verilog ../rtl/{project_name}.v
hierarchy -top {project_name}
proc
check -assert
"""
    (project_dir / "syn" / "presynth_check.ys").write_text(presynth_content)

    # 4. Yosys run_synth.ys: <name>/syn/run_synth.ys
    run_synth_content = f"""# read design files
read_verilog ../rtl/{project_name}.v

# synthesize top module
synth -top {project_name}

# mapping to generic gates
abc -g cmos2

# optimization and cleanup
opt_clean

# print statistics
stat

# write synthesizable netlist complying with .gitignore (*_syn.v)
write_verilog -noattr {project_name}_syn.v
"""
    (project_dir / "syn" / "run_synth.ys").write_text(run_synth_content)

    # 5. Makefile: <name>/Makefile
    makefile_content = f"""# Makefile for {project_name} project

VERILATOR = verilator
IVERILOG  = iverilog
VVP       = vvp
YOSYS     = yosys

RTL_DIR = rtl
TB_DIR  = tb
SIM_DIR = sim
SYN_DIR = syn
GLS_DIR = gls

RTL_SRCS = $(RTL_DIR)/{project_name}.v
TB_SRCS  = $(TB_DIR)/tb_{project_name}.v
SYN_YS   = $(SYN_DIR)/run_synth.ys
SYN_NETLIST = $(SYN_DIR)/{project_name}_syn.v
SIM_CELLS = /usr/share/yosys/simlib.v

.PHONY: all lint presynth_check rtl_sim syn gls_sim pnr pnr_qor clean

all: lint presynth_check rtl_sim syn gls_sim

lint:
	$(VERILATOR) --lint-only -Wall -Werror-MULTIDRIVEN -Wno-fatal $(RTL_SRCS)

presynth_check:
	cd $(SYN_DIR) && $(YOSYS) -s presynth_check.ys

rtl_sim:
	cd $(SIM_DIR) && $(IVERILOG) -o rtl_sim.out $(addprefix ../, $(TB_SRCS)) $(addprefix ../, $(RTL_SRCS))
	cd $(SIM_DIR) && $(VVP) rtl_sim.out

syn:
	cd $(SYN_DIR) && $(YOSYS) -s run_synth.ys

gls_sim: syn
	cd $(SIM_DIR) && $(IVERILOG) -DGATE_SIM -o gls_sim.out ../$(TB_SRCS) ../$(SYN_NETLIST) $(SIM_CELLS)
	cd $(SIM_DIR) && $(VVP) gls_sim.out
	mv $(SIM_DIR)/tb_{project_name}.vcd $(GLS_DIR)/ || true
	mv $(SIM_DIR)/gls_sim.out $(GLS_DIR)/ || true

# 5. PnR Flow
pnr:
	python3 ../tools/run_pnr.py {project_name}

# 6. PnR QoR Report
pnr_qor:
	../tools/report_qor_phases.py ../librelane_designs/{project_name}/runs/run_100MHz

clean:
	rm -f $(SIM_DIR)/rtl_sim.out $(SIM_DIR)/tb_{project_name}.vcd
	rm -f $(GLS_DIR)/gls_sim.out $(GLS_DIR)/tb_{project_name}.vcd
	rm -f $(SYN_DIR)/{project_name}_syn.v
"""
    (project_dir / "Makefile").write_text(makefile_content)

    # 6. AGENTS.md: <name>/AGENTS.md
    agents_content = f"""# Subproject: {project_name}

## 1. Overview
This is a standard EDA testbed subproject for `{project_name}`.

## 2. Directory Structure
- `docs/`: Module specifications and design documentation (`spec.md`)
- `rtl/`: Synthesizable Verilog RTL source files (`{project_name}.v`)
- `tb/`: Testbench files (`tb_{project_name}.v`)
- `sim/`: RTL simulation outputs (`rtl_sim.out`, waveforms)
- `syn/`: Logic synthesis outputs (`run_synth.ys`, `{project_name}_syn.v`)
- `gls/`: Gate-Level Simulation outputs (`gls_sim.out`)

## 3. Automation Commands
```bash
make lint           # Verilator lint check
make presynth_check # Pre-synthesis AST check
make rtl_sim        # RTL simulation using Icarus Verilog
make syn            # Logic synthesis using Yosys
make gls_sim        # Gate-Level Simulation
```

## 4. Physical Design (PnR Setup)
To configure PnR for this module, use the `pnr-setup` skill:
Ask the agent: "Set up PnR for {project_name}".
"""
    (project_dir / "AGENTS.md").write_text(agents_content)

    print(f"Successfully created project '{project_name}' at: {project_dir}")

def main():
    parser = argparse.ArgumentParser(description="Create a new circuit design subproject with standard directory structure and templates.")
    parser.add_argument("--name", "-n", required=True, help="Name of the project/module (e.g. my_fifo)")
    parser.add_argument("--force", action="store_true", help="Overwrite existing project directory")
    args = parser.parse_args()

    create_project(args.name, args.force)

if __name__ == "__main__":
    main()
