# UART Controller テスト計画

## 1. 概要
本ドキュメントは、VDRV_v1aにおける `uart_ctrl` ブロックの機能検証計画を定義する。
ホストからのシリアル通信パケットを正確にパースし、3ビット拡張された負荷状態（`step_state[2:0]`）および各種制御コマンドが期待通りに後段へ出力されることを検証する。

## 2. 検証対象モジュール
- 対象ブロック: `uart_ctrl` (相対パス: `blocks/uart_ctrl/rtl/uart_ctrl.v`)
- 構成サブモジュール: `uart_rx.v`, `uart_tx.v`, `uart_pkt_parser.v`
- テストベンチ: `tb_uart_ctrl` (相対パス: `blocks/uart_ctrl/tb/tb_uart_ctrl.v`)

## 3. 検証項目

### 3.1 UART受信およびプロトコルデコード
1. **プリアンブル検出**: ヘッダバイト `0xAA 0x55` を正しく検出し、異常データ受信時には待機状態へフォールバックすること。
2. **ボーレート整合性**: 100MHzクロック環境下で115200bps相当（868クロック/ビット）のサンプリングが正常に行われること。

### 3.2 3ビット負荷状態デコード (CMD_SET_STEP)
`CMD_SET_STEP` パケット受信時、Byte 3のビット `[6:4]` から抽出される3ビット負荷状態 `{cpu_en, crc_en, mac_en}` とステップID、および継続時間が正しくデコードされること。
- Case 1: `3'b001` (MAC_ONLY)
- Case 2: `3'b010` (CRC_ONLY)
- Case 3: `3'b011` (MAC_CRC)
- Case 4: `3'b111` (ALL_FULL)

### 3.3 シーケンス制御コマンドデコード
1. **CMD_START_SEQ**: `0xAA 0x55 0x02` 受信時に `cmd_start_seq` パルスが出力されること。
2. **CMD_STOP_SEQ**: `0xAA 0x55 0x03` 受信時に `cmd_stop_seq` パルスが出力されること。

## 4. 実行手順
`blocks/uart_ctrl/` ディレクトリにて以下のコマンドを実行する。
```bash
make lint            # Verilator による静的構文・接続チェック
make presynth_check  # Yosys による事前論理チェック
make unit_sim        # Icarus Verilog による単体シミュレーション
make syn             # Yosys による論理合成チェック
```
