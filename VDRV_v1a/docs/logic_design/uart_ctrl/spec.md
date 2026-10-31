# VDRV_v1a UART Controller 仕様書

## 1. 概要
UARTコントローラ（`uart_ctrl`）は、外部ホストとシステム間のシリアル通信を担うモジュールである。主に負荷シーケンサ（`load_sequencer`）に対するステップ設定（`CMD_SET_STEP`）やシーケンスの開始（`CMD_START_SEQ`）・停止（`CMD_STOP_SEQ`）などのコマンドパケットの受信およびデコードを行う。

VDRV_v1aアーキテクチャでは、負荷生成コアの構成変更（MACコア、CRCコア、CPUコア）に伴い、負荷状態指定（`step_state`）が従来の2ビットから3ビット（`[2:0] = {cpu_en, crc_en, mac_en}`）へと拡張されている。

## 2. 通信仕様
- **ボーレート**: 115200 bps
- **基準クロック**: 100 MHz (周期 10 ns)
- **1ビットあたりのクロック数 (CLK_PER_BIT)**: 868 (`100MHz / 115200bps ≈ 868`)
- **データフォーマット**: 8データビット、パリティなし、1ストップビット (8-N-1)

## 3. コマンドパケット仕様

### 3.1 パケットフォーマット
ホストから送信されるパケットはヘッダ `0xAA 0x55` で開始される。

| バイト番号 | フィールド | 説明 |
| :--- | :--- | :--- |
| Byte 0 | Header 1 | 固定値 `0xAA` |
| Byte 1 | Header 2 | 固定値 `0x55` |
| Byte 2 | Command ID | コマンド種別<br>・`0x01`: `CMD_SET_STEP`<br>・`0x02`: `CMD_START_SEQ`<br>・`0x03`: `CMD_STOP_SEQ` |
| Byte 3 | Data 1 | `CMD_SET_STEP` 時: `{1'b0, step_state[2:0], step_id[3:0]}` |
| Byte 4 | Data 2 | `CMD_SET_STEP` 時: `step_duration[15:8]` (継続時間上位バイト) |
| Byte 5 | Data 3 | `CMD_SET_STEP` 時: `step_duration[7:0]` (継続時間下位バイト) |

### 3.2 負荷状態 (step_state[2:0]) 定義
`step_state[2:0]` は各負荷コアのイネーブル信号 `{cpu_en, crc_en, mac_en}` に対応する。

| step_state[2:0] | モード名 | CPU | CRC Load | MAC Load | 説明 |
| :---: | :--- | :---: | :---: | :---: | :--- |
| `3'b000` | IDLE | 停止 | 停止 | 停止 | 全負荷コアアイドル |
| `3'b001` | MAC_ONLY | 停止 | 停止 | 動作 | MAC Load Coreのみ動作 |
| `3'b010` | CRC_ONLY | 停止 | 動作 | 停止 | CRC Load Coreのみ動作 |
| `3'b011` | MAC_CRC | 停止 | 動作 | 動作 | MAC & CRC同時動作 |
| `3'b100` | CPU_ONLY | 動作 | 停止 | 停止 | CPUコアのみ動作 |
| `3'b101` | CPU_MAC | 動作 | 停止 | 動作 | CPU & MAC同時動作 |
| `3'b110` | CPU_CRC | 動作 | 動作 | 停止 | CPU & CRC同時動作 |
| `3'b111` | ALL_FULL | 動作 | 動作 | 動作 | 全負荷コア同時動作 |

## 4. モジュール構成と入出力インターフェース

### 4.1 内部モジュール構成
- `uart_rx` (相対パス: `blocks/uart_ctrl/rtl/uart_rx.v`): シリアル受信信号（`rx`）をサンプリングし、8ビットパラレルデータ（`rx_data`）および有効フラグ（`rx_valid`）を出力。
- `uart_tx` (相対パス: `blocks/uart_ctrl/rtl/uart_tx.v`): 送信モジュール（現状は予約ダミー接続）。
- `uart_pkt_parser` (相対パス: `blocks/uart_ctrl/rtl/uart_pkt_parser.v`): 受信データを状態遷移機械によりパースし、各コマンドおよび設定信号を出力。

### 4.2 信号定義

| 信号名 | 方向 | ビット幅 | 説明 |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | システムクロック (100 MHz) |
| `rst_n` | Input | 1 | 非同期リセット（Active Low） |
| `rx` | Input | 1 | UARTシリアル受信データ入力 |
| `tx` | Output | 1 | UARTシリアル送信データ出力 |
| `cmd_set_step` | Output | 1 | ステップ設定パルス（1クロック幅） |
| `cmd_start_seq` | Output | 1 | シーケンス開始コマンドパルス |
| `cmd_stop_seq` | Output | 1 | シーケンス停止コマンドパルス |
| `step_id` | Output | 4 | 設定対象ステップID (0〜15) |
| `step_state` | Output | 3 | 3ビット負荷状態 (`{cpu_en, crc_en, mac_en}`) |
| `step_duration` | Output | 16 | ステップ継続時間 (Tick数単位、1 Tick=0.5us) |
