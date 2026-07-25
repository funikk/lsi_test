# VDRV_v1 UART Controller仕様書

## 1. 概要
UARTコントローラは、外部ホストとシステム間の通信を担う。主にLoad Sequencerへのコマンドパケットの送受信に使用される。

## 2. 通信仕様
- **ボーレート**: 115200 bps
- **システムクロック**: 100 MHz
- **1ビットあたりのクロック数 (clk_per_bit)**: 868 (`100MHz / 115200bps ≈ 868`)
- **データ長**: 8 bit
- **パリティ**: なし
- **ストップビット**: 1 bit

## 3. バイナリパケットフォーマット
ホストから送信されるコマンドおよびステータス要求は、固定長(8バイト)のバイナリパケットフォーマットを使用する。

| バイト位置 | フィールド名 | 説明 |
| :--- | :--- | :--- |
| Byte 0 | Header 1 | 固定値 `0xAA` |
| Byte 1 | Header 2 | 固定値 `0x55` |
| Byte 2 | Command ID | コマンド種別<br>・`0x01`: CMD_SET_STEP<br>・`0x02`: CMD_START_SEQ<br>・`0x03`: CMD_STOP_SEQ<br>・`0x04`: CMD_GET_STATUS |
| Byte 3 | Step ID / Param | コマンドパラメータ。<br>CMD_SET_STEP時は対象のStep ID (0～15)を指定。 |
| Byte 4 | State | 負荷状態指定 (CMD_SET_STEP時のみ有効)<br>・`00`: IDLE<br>・`01`: AES_FULL<br>・`10`: CPU_FULL<br>・`11`: BOTH_FULL |
| Byte 5 | Duration (Low) | 継続時間の下位8ビット。単位はTick (1 Tick = 0.5us)。 |
| Byte 6 | Duration (High)| 継続時間の上位8ビット。単位はTick (1 Tick = 0.5us)。 |
| Byte 7 | Checksum | Byte 2 から Byte 6 までのXOR値。 |

## 4. インターフェース信号 (UART Controller ⇔ Load Sequencer)
UARTコントローラとLoad Sequencer間のインターフェースは以下の信号により構成される。

| 信号名 | 方向 (UART側) | 説明 |
| :--- | :--- | :--- |
| `cmd_valid` | Output | 受信パケットのパースが完了し、コマンドが有効であることを示す |
| `cmd_id[7:0]` | Output | 受信したコマンドID |
| `cmd_step_id[3:0]` | Output | 設定対象のStep ID |
| `cmd_state[1:0]` | Output | 設定する負荷状態 (State) |
| `cmd_duration[15:0]` | Output | 設定する継続時間 (Tick数) |
| `status_req` | Output | ステータス要求 (CMD_GET_STATUS受信時) |
| `seq_status[31:0]` | Input | Load Sequencerの現在ステータス (ホスト返送用) |
| `seq_status_valid` | Input | seq_statusが有効であることを示す |
