# Project Overview: LSI Testbed (Open EDA Flow)

This project is a sandbox environment for studying LSI design, logic synthesis, and physical design (Placement & Routing / PnR) preparation using open-source EDA tools. 

---

## 1. Directory Structure

Each design project follows a standard industry directory structure:

```text
lsi_test/
├── AGENTS.md                  # Project overview and developer reference (this file)
├── docs/                      # Setup guides and best practices
│   ├── open_source_eda_setup.md
│   ├── verilog_best_practices.md
│   └── upgrade_eda_tools.md
├── counter_test/              # Project 1: Simple 8-bit Counter
│   ├── AGENTS.md              # Counter-specific reference
│   └── ... (standard subdirs: rtl, tb, sim, syn, gls)
├── fifo_test/                 # Project 2: Synchronous FIFO (ASIC/PnR testbed)
│   ├── AGENTS.md              # Synchronous FIFO-specific reference
│   └── ... (standard subdirs: rtl, tb, sim, syn, gls)
├── async_fifo_test/           # Project 3: Asynchronous FIFO (CDC/PnR testbed)
│   ├── AGENTS.md              # Asynchronous FIFO-specific reference
│   └── ... (standard subdirs: rtl, tb, sim, syn, gls)
├── mac_array_test/            # Project 4: MAC Array (Systolic Array for IR-Drop)
│   ├── AGENTS.md              # MAC Array-specific reference
│   └── ... (standard subdirs: rtl, tb, sim, syn, gls)
├── aes_prng_test/             # Project 5: AES-128 PRNG (High-Switching IR-Drop Motif)
│   ├── AGENTS.md              # AES PRNG-specific reference
│   └── ... (standard subdirs: rtl, tb, sim, syn, gls)
└── cpu_aes_prng_test/         # Project 6: CPU + AES/PRNG Integrated Stress Testbed
    ├── AGENTS.md              # CPU + AES/PRNG-specific reference
    └── ... (standard subdirs: rtl, docs, firmware, tb, sim, syn, gls)
```

Within each design project subdirectory, the following structure is maintained:
*   `rtl/`: Contains synthesizable RTL Verilog source files.
*   `tb/`: Contains testbench files.
*   `sim/`: Output directory for RTL simulations (VCD waves, logs, simulation executables).
*   `syn/`: Output directory for logic synthesis (Yosys scripts, logs, netlists, SDC constraints).
*   `gls/`: Output directory for Gate-Level Simulations (GLS logs, waves, GLS executables).

---

## 2. Configured EDA Tools

The following open-source tools are installed and verified:
*   **Linter (Static Analysis)**: Verilator (v5.032)
*   **Simulator**: Icarus Verilog (v12.0 stable) & VVP
*   **Logic Synthesis**: Yosys (v0.52)
*   **Waveform Viewer**: GTKWave (v3.3.117+)

---

## 3. Automation Commands (Makefile)

A `Makefile` is located in the root of each project subdirectory (`counter_test/`, `fifo_test/`, `async_fifo_test/`, `mac_array_test/`, `aes_prng_test/`, `cpu_aes_prng_test/`). The available targets are:

```bash
# Clean all temporary files (sim results, netlists, wave dumps)
make clean

# Run lint checks on RTL (Verilator)
make lint

# Run pre-synthesis fast quality check (Yosys proc & check -assert, 0.7s)
make presynth_check

# Run RTL Simulation (output files go into sim/)
make rtl_sim

# Run Logic Synthesis (netlist is generated in syn/)
make syn

# Run Gate-Level Simulation using Yosys cell library (results go into gls/)
make gls_sim

# Run PnR flow (physical design)
make pnr

# Report phase-by-phase QoR & runtime table (hh:mm:ss format)
make pnr_qor

# Run all verification phases (lint -> presynth_check -> rtl_sim -> syn -> gls_sim)
make all
```

---

## 4. Key References and Guides

### Documentation Guides
*   [EDA Setup Guide](docs/open_source_eda_setup.md): Guide for installing tools and running baseline simulations.
*   [Verilog Best Practices](docs/verilog_best_practices.md): Synthesizable RTL design guidelines.
*   [Tool Upgrade Guide](docs/upgrade_eda_tools.md): Instruction on compiling newer tool versions or using OSS CAD Suite.
*   [PnR Flow Guide](docs/librelane_pnr_flow_guide.md): Guide for running physical design (PnR) on new modules using LibreLane.

### Subproject Reference Guides (AGENTS.md)
*   [Counter Project Guide](counter_test/AGENTS.md): Simple 8-bit Counter.
*   [Synchronous FIFO Project Guide](fifo_test/AGENTS.md): Parameterizable Sync FIFO.
*   [Asynchronous FIFO Project Guide](async_fifo_test/AGENTS.md): CDC Asynchronous FIFO.
*   [MAC Array Project Guide](mac_array_test/AGENTS.md): Systolic Array for PnR/IR-Drop testing.
*   [AES PRNG Project Guide](aes_prng_test/AGENTS.md): Self-stimulating AES core for high-switching IR-Drop testing.
*   [CPU + AES/PRNG Project Guide](cpu_aes_prng_test/AGENTS.md): Integrated RISC-V CPU + AES-DMA Subsystem for IR-Drop stress testing.
*   [VDRV_v1 Project Guide](VDRV_v1/AGENTS.md): Voltage Drop on RISC-V v1 multi-block ASIC testbed with dual-mode hybrid sequencer.

---

## 5. Documentation & Path Guidelines

When writing documentation and configuration files (such as `config.json` or Makefiles), adhere to the following path specification rules:

* **Prohibition of Absolute Paths**:
  * Do not write absolute paths that depend on the host environment.
* **Adoption of Relative Paths / Project Root Paths**:
  * For file references in documents and path definitions in configuration files, always use relative paths from the project root (e.g., `docs/verilog_best_practices.md` or `../rtl/picorv32.v`).
  * Utilize the `dir::` notation in configuration files like those for LibreLane.
  * If absolute paths are required in shell scripts, obtain/define them dynamically using `$(pwd)` or environment variables (such as `$WORKSPACE`).
* **Language Policy**
  * **Agent-facing documentation (rules, agent configurations, orchestration guidelines)** MUST be written in English to ensure accurate interpretation by LLM agents.
  * **User-facing documentation (specifications, setup guides, architectural documents)** should be written in Japanese to support the development team.

## 6. Agent Orchestration & Task Delegation Rules

The following specialized subagents are defined in this project. It is highly recommended to delegate tasks and collaborate with them (using `invoke_subagent` / `send_message`) as necessary.

* **project_manager**: Overall task breakdown, orchestration, and final verification of artifacts.
* **system_architect**: System architecture design, specification drafting, and HW/SW partitioning.
* **logic_design**: RTL implementation (Verilog), block integration, and linting.
* **logic_verification**: Testbench implementation, coverage verification, and GLS.
* **firmware_design**: Firmware (C/Assembly) development and test vector provision.
* **backend_design**: Physical implementation (Logic synthesis, PnR, STA).
* **methodology_engineer**: Development flow automation, Makefile construction, and DevOps.


The parent agent (or Project Manager) must strictly adhere to the following rules when assigning tasks to subagents and receiving completion reports:

1. **Explicit Definition of Done**:
   When assigning a task, always include the "expected artifacts (file paths)", "verification commands to run (e.g., `make rtl_sim`)", and "expected outputs to check" in the prompt.
2. **Verification of Artifacts**:
   Do not take a text report of "completed" from a subagent at face value. Always use tools to verify that the artifacts have actually been created or updated in the local filesystem.
3. **Rejection & Retry**:
   If the actual file is not generated or the command execution log does not exist, the parent agent must not take over and perform the work itself. Demand a retry from the subagent: "The file was not created. Instead of outputting mock text, use your tools to write the file and execute the commands."
4. **Ensuring Agent Permissions & Workflow Skill References (Dynamic Definition Required)**:
   Do NOT simply invoke subagents using pre-existing static definitions if they require tool access. You MUST dynamically define the subagent first using the `define_subagent` tool and explicitly set `enable_write_tools: true` (for file/command execution) or `enable_subagent_tools: true` (for nested invocation).
   To simplify invocation and eliminate file inspection overhead, pass a concise `system_prompt` instructing the subagent to load its role workflow skill in `.agents/skills/<role-name>/SKILL.md` (e.g. `system_prompt: "You are the Logic Design Engineer. Read and strictly follow your workflow skill in .agents/skills/logic-design/SKILL.md before taking action."`).

