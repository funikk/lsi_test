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

---

## 5. Documentation & Path Guidelines

ドキュメントの作成および設定ファイル（`config.json` や Makefile 等）の記述時は、以下のパス指定ルールを遵守してください。

* **絶対パスの禁止**:
  * ホスト環境に依存する絶対パスの記述は行わないでください。
* **相対パス / プロジェクトルートパスの採用**:
  * ドキュメント内のファイル参照や設定ファイルのパス定義には、必ずプロジェクトルートからの相対パス（例: `docs/verilog_best_practices.md` や `../rtl/picorv32.v`）を使用してください。
  * LibreLane などの設定ファイルでは `dir::` 記法を活用してください。
  * シェルスクリプト等で絶対パスが必要な場合は `$(pwd)` または環境変数（`$WORKSPACE` 等）を用いて動的に取得・定義してください。

## 6. Agent Orchestration & Task Delegation Rules

親エージェント（またはProject Manager）がサブエージェントにタスクを依頼する際、および完了報告を受け取る際は、以下のルールを厳守してください。

1. **完了条件（Definition of Done）の明示**:
   タスクを依頼する際は、必ず「期待する成果物（ファイルパス）」と「実行すべき検証コマンド（例: `make rtl_sim`）」、および「確認すべき出力結果」をプロンプトに含めてください。
2. **実ファイルの確認（Verification of Artifacts）**:
   サブエージェントから「完了した」というテキスト報告を受けた場合、直ちに鵜呑みにしてはいけません。必ずツールを用いて、ローカルファイルシステム上に成果物が実際に作成・更新されているかを確認してください。
3. **差し戻し（Rejection & Retry）**:
   実ファイルが生成されていない、またはコマンド実行ログが存在しない場合、親エージェント自身が作業を巻き取って代行してはいけません。「ファイルが作成されていません。モックテキストを出力するのではなく、ツールを用いて実際にファイルを書き出し、コマンドを実行してください」とサブエージェントに差し戻し（リトライ）を要求してください。
