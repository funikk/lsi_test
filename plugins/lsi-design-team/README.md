# LSI Design Team Plugin (`lsi-design-team`)

A reusable, multi-role agent team framework for LSI, ASIC, and FPGA design, verification, and physical implementation.

## Overview
This plugin provides an orchestrated team of specialized engineer skills (Project Manager, System Architect, Logic Design, Logic Verification, Firmware Design, Backend Design, Methodology Engineer).

## Features
- **Toolchain Agnostic**: Supports **LibreLane (Open-Source ASIC)**, **Intel / Altera Quartus (FPGA)**, and **Commercial ASIC** toolchains via `resources/` references.
- **Workflow-Driven Roles**: Each engineer role is defined as a workflow skill with Seniority Level personas.
- **Project Initializer**: Automatically generates standard project directory structures (`rtl/`, `tb/`, `pnr/`, `docs/`).

## Toolchain Support
1. **`librelane`**: Open-Source ASIC Synthesis, PnR, STA via Yosys & OpenROAD.
2. **`quartus`**: Intel/Altera FPGA Synthesis, Fitting, Timing Analysis via Quartus Prime CLI.
3. **`commercial_asic`**: Synopsys / Cadence ASIC toolchains.
