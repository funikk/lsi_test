# VDRV_v1a Load Sequencer 仕様書

## 1. 概要
負荷シーケンサ（`load_sequencer`）は、VDRV_v1aチップ内部において、規定されたマルチコア負荷パターン（シーケンス）を高精度かつ自律的に生成・制御するハードウェアモジュールである。

本モジュールは、MAC負荷コア（`mac_load_core`）、CRC負荷コア（`crc_load_core`）、およびCPUコア（`picorv32_cpu`）の3系統の負荷状態（`{cpu_en, crc_en, mac_en}`）を最大16ステップにわたって時系列制御する。

## 2. タイムベース設計 (Tick Timer)
各シーケンスステップの継続時間を管理するための高精度基準Tickタイマーを内蔵する。
- **システムクロック**: 100 MHz (1周期 10 ns)
- **1 Tickの長さ**: 0.5 us (500 ns)
- **Tick分周カウント数**: 50 サイクル (10 ns * 50 = 500 ns = 0.5 us)
各ステップの継続時間（Duration）は、この0.5us Tickを単位として16ビットで設定される（最大 65535 Ticks ≒ 32.7 ms）。

## 3. レジスタマップおよびメモリ仕様
シーケンサ内部に最大16ステップ（Step 0〜15）のシーケンスメモリを内蔵する。
MMIO空間（ベースアドレス `0x8000_0100`、デコード条件 `mem_addr[31:8] == 24'h8000_01`）上に以下のレジスタが配置される。

| オフセット | レジスタ名 | 属性 | ビット定義と説明 |
| :--- | :--- | :---: | :--- |
| `0x00` | `SEQ_CTRL` | R/W | **シーケンサ制御レジスタ**<br>・bit[0]: `irq_mode` (0: HW-Directモード, 1: CPU-IRQモード)<br>・bit[1]: `seq_enable` (1: シーケンス開始, 0: 停止)<br>・bit[3:2]: 予約 (2'b00)<br>・bit[7:4]: `total_steps[3:0]` (実行総ステップ数 0〜15)<br>・bit[31:8]: 予約 (24'h0) |
| `0x04` | `SEQ_STATUS` | RO | **シーケンサ状態レジスタ**<br>・bit[3:0]: `current_step[3:0]` (現在実行中ステップID)<br>・bit[6:4]: `seq_state[current_step][2:0]` (現在ステップの負荷状態)<br>・bit[7]: `running` (動作中フラグ)<br>・bit[15:8]: 予約 (8'h00)<br>・bit[31:16]: `duration_cnt[15:0]` (現在ステップの残りTick数) |
| `0x08` | `REG_LOAD_STATE` | RO | **CPU負荷状態読み出しレジスタ**<br>・bit[2:0]: `cpu_load_state[2:0]`<br>・bit[31:3]: 予約 (29'h0) |
| `0x10`〜`0x4C` | `STEP_REG[0..15]` | R/W | **各ステップ設定レジスタ** (オフセット: `0x10 + 4 * idx`)<br>・bit[15:0]: `seq_duration[idx][15:0]` (ステップ継続時間Tick)<br>・bit[18:16]: `seq_state[idx][2:0]` (`{cpu_en, crc_en, mac_en}`)<br>・bit[31:19]: 予約 (13'h0) |

*(注: 各ステップの設定は、UARTコントローラからのパケットコマンド `cmd_set_step` からも直接書き込み可能)*

## 4. 負荷状態の出力論理
シーケンスメモリ `seq_state[0:15]` の各エントリは3ビット `{cpu_en, crc_en, mac_en}` で構成される。

- **シーケンサ動作中 (`running == 1`)**:
  - `mac_load_mode_en <= seq_state[current_step][0];`
  - `crc_load_mode_en <= seq_state[current_step][1];`
  - `cpu_load_state   <= seq_state[current_step];`
- **シーケンサ停止時 (`running == 0`)**:
  - `mac_load_mode_en <= 1'b0;`
  - `crc_load_mode_en <= 1'b0;`
  - `cpu_load_state   <= 3'b000;`

## 5. デュアルモード・ハイブリッド動作

### 5.1 IRQ_MODE = 0 (HW-Direct Mode)
CPUの割り込み処理を一切介さず、シーケンサ自身がサイクル精度で負荷コアのイネーブル信号を直接駆動する。
- 出力信号: `hw_direct_active = running && !irq_mode;` によりアサート。
- 特徴: CPUの割り込みサービスルーチン（ISR）実行に伴うノイズを完全に排除し、MACコアやCRCコアの純粋な過渡負荷変動と電圧降下波形（IR-Drop）を観測可能。

### 5.2 IRQ_MODE = 1 (CPU-IRQ Transient Mode)
各ステップの継続時間が満了し次のステップへ進むタイミングで、CPUに対して割り込みパルス（`cpu_irq`）を1クロック幅出力する。
- 出力信号: `hw_direct_active` は低レベル (0) に固定。
- 特徴: 割り込みを契機としてCPUがスリープから復帰する際の急峻な電流変化（$di/dt$ CPU wake-up transient）を意図的に励起し、システム過渡応答を評価可能。

## 6. 入出力インターフェース信号一覧

| 信号名 | 方向 | ビット幅 | 説明 |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | システムクロック (100 MHz) |
| `rst_n` | Input | 1 | 非同期リセット（Active Low） |
| `cmd_set_step` | Input | 1 | UARTからのステップ設定パルス |
| `cmd_start_seq` | Input | 1 | UARTからのシーケンス開始要求 |
| `cmd_stop_seq` | Input | 1 | UARTからのシーケンス停止要求 |
| `step_id` | Input | 4 | 設定対象ステップID (0〜15) |
| `step_state` | Input | 3 | 設定負荷状態 (`{cpu_en, crc_en, mac_en}`) |
| `step_duration` | Input | 16 | 設定継続時間Tick |
| `mem_wdata` | Input | 32 | MMIOライトデータ |
| `mem_wstrb` | Input | 4 | MMIOバイトライトイネーブル |
| `mem_valid` | Input | 1 | MMIOアクセス有効信号 |
| `mem_addr` | Input | 32 | MMIOアクセスアドレス |
| `mem_rdata` | Output | 32 | MMIOリードデータ |
| `mem_ready` | Output | 1 | MMIO応答レディ信号 |
| `mac_load_mode_en` | Output | 1 | MAC Load Core 負荷動作イネーブル |
| `crc_load_mode_en` | Output | 1 | CRC Load Core 負荷動作イネーブル |
| `hw_direct_active` | Output | 1 | HW-Direct動作中フラグ (`running && !irq_mode`) |
| `cpu_load_state` | Output | 3 | CPU向け負荷状態信号 (`[2:0]`) |
| `cpu_irq` | Output | 1 | CPU向けステップ遷移割り込みパルス |
