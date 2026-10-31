# Load Sequencer 検証レポート

## 1. 検証結果概要
- **ブロック名**: `load_sequencer`
- **検証結果ステータス**: **PASS** (全項目合格、エラー0件)
- **シミュレータ**: Icarus Verilog (v12.0)
- **リンタ**: Verilator (v5.032)
- **論理合成**: Yosys (v0.52)
- **テストベンチ**: `blocks/load_sequencer/tb/tb_load_sequencer.v`

## 2. 実行結果詳細

### 2.1 静的解析 (Lint Check)
```text
verilator --lint-only -Wall -I../../common/rtl -Irtl rtl/load_sequencer.v
- Verilator: Built from 0.027 MB sources in 2 modules
Result: 0 errors, 0 warnings
```

### 2.2 事前論理チェック (Pre-synthesis Check)
```text
yosys -p "read_verilog -I../../common/rtl -Irtl rtl/load_sequencer.v; proc; check -assert"
Checking module load_sequencer...
Found and reported 0 problems.
```

### 2.3 機能シミュレーション (Unit Sim)
```text
VCD info: dumpfile tb_load_sequencer.vcd opened for output.
PASS: Initial reset state verified.
--- 1. Programming steps via UART ---
--- 2. MMIO readback of STEP_REG ---
PASS: MMIO STEP_REG[0] readback (0x10) = 0x00010002
PASS: MMIO STEP_REG[1] readback (0x14) = 0x00020002
--- 3. MMIO write and readback of STEP_REG[4] (0x20) ---
PASS: MMIO STEP_REG[4] (0x20) write/read verified: 0x00040005
--- 4. MMIO control and status readback before run ---
PASS: MMIO SEQ_CTRL readback (0x00) = 0x00000030
PASS: MMIO REG_LOAD_STATE readback (0x08) = 0x00000000
--- 5. HW-Direct Mode Execution (irq_mode=0) ---
PASS: hw_direct_active asserted correctly.
PASS: Step 0 outputs: mac_en=1, crc_en=0, cpu_load_state=001
PASS: MMIO SEQ_STATUS (0x04) running=1, state=3'b001, step=0 (0x00020090)
PASS: MMIO REG_LOAD_STATE (0x08) readback = 0x00000001
PASS: Step 1 outputs: mac_en=0, crc_en=1, cpu_load_state=010
PASS: Step 2 outputs: mac_en=1, crc_en=1, cpu_load_state=011
PASS: Step 3 outputs: mac_en=1, crc_en=1, cpu_load_state=111
PASS: Zero cpu_irq events in HW-Direct mode verified.
--- 6. Stopping sequence via MMIO ---
PASS: Sequencer stopped; outputs cleared.
--- 7. IRQ Mode and UART Start/Stop ---
PASS: hw_direct_active is correctly 0 in IRQ mode.
PASS: cpu_irq generated 2 interrupts as expected in IRQ mode.
PASS: Sequencer stopped via UART; outputs cleared.
============================================
ALL LOAD_SEQUENCER TESTS PASSED (errors=0)
============================================
```

### 2.4 論理合成チェック (Synthesis)
```text
yosys -p "read_verilog -I../../common/rtl -Irtl rtl/load_sequencer.v; proc; check -assert; write_verilog -noattr syn/load_sequencer_gate.v"
Result: 正常完了 (syn/load_sequencer_gate.v 生成確認済み)
```

## 3. 総括
- UARTインターフェースによるステップ設定およびMMIO（`0x00`, `0x04`, `0x08`, `0x10〜0x4C`）による読み出し・書き込み動作が設計仕様通りであることを確認した。
- HW-Directモード（`irq_mode = 0`）において、`hw_direct_active` 信号のアサート下で各ステップの負荷イネーブル信号（`mac_load_mode_en`, `crc_load_mode_en`, `cpu_load_state`）がサイクル精度で正確に遷移することを確認した。
- CPU-IRQモード（`irq_mode = 1`）において、`hw_direct_active` が低レベルを維持し、ステップ境界で `cpu_irq` パルスが正確に出力されることを確認した。
- UART経由の開始・停止（`cmd_start_seq`, `cmd_stop_seq`）およびMMIO経由の停止（`seq_enable = 0`）により、負荷状態が安全に0クリアされることを確認した。
