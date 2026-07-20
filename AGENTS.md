# Project Overview: LSI Testbed (Open EDA Flow)

This project is a sandbox environment for studying LSI design, logic synthesis, and physical design (Placement & Routing / PnR) preparation using open-source EDA tools. 

---


## Available Specialized Subagents
本プロジェクトでは以下の専門エージェントが定義されており、必要に応じて互いにタスクを委譲・連携（invoke_subagent / send_message）することが推奨されます。
* **project_manager**: 全体のタスク分解、オーケストレーション、最終成果物の検収
* **system_architect**: システムアーキテクチャ設計、仕様策定、HW/SW分割
* **logic_design**: RTL実装（Verilog）、ブロック統合、Lint確認
* **logic_verification**: テストベンチ実装、カバレッジ検証、GLS
* **firmware_design**: ファームウェア（C/アセンブリ）開発、テストベクタ提供
* **backend_design**: 物理実装（論理合成、配置配線、STA）
* **methodology_engineer**: 開発フロー自動化、Makefile構築、DevOps

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

---

## 5. Documentation & Path Guidelines

When writing documentation and configuration files (such as `config.json` or Makefiles), adhere to the following path specification rules:

* **Prohibition of Absolute Paths**:
  * Do not write absolute paths that depend on the host environment.
* **Adoption of Relative Paths / Project Root Paths**:
  * For file references in documents and path definitions in configuration files, always use relative paths from the project root (e.g., `docs/verilog_best_practices.md` or `../rtl/picorv32.v`).
  * Utilize the `dir::` notation in configuration files like those for LibreLane.
  * If absolute paths are required in shell scripts, obtain/define them dynamically using `$(pwd)` or environment variables (such as `$WORKSPACE`).

## 6. Agent Orchestration & Task Delegation Rules

The parent agent (or Project Manager) must strictly adhere to the following rules when assigning tasks to subagents and receiving completion reports:

1. **Explicit Definition of Done**:
   When assigning a task, always include the "expected artifacts (file paths)", "verification commands to run (e.g., `make rtl_sim`)", and "expected outputs to check" in the prompt.
2. **Verification of Artifacts**:
   Do not take a text report of "completed" from a subagent at face value. Always use tools to verify that the artifacts have actually been created or updated in the local filesystem.
3. **Rejection & Retry**:
   If the actual file is not generated or the command execution log does not exist, the parent agent must not take over and perform the work itself. Demand a retry from the subagent: "The file was not created. Instead of outputting mock text, use your tools to write the file and execute the commands."

4. **サブエージェントの権限担保 (Ensuring Agent Permissions)**:
   サブエージェントを定義・呼び出す際は、必ずそのタスクに応じたツール実行権限を与えてください。他のエージェントを呼び出す場合は `enable_subagent_tools: true` を、ファイル作成やターミナルコマンド（`run_command`）を実行させる場合は `enable_write_tools: true` を設定しなければ、モック回答の温床となります。
