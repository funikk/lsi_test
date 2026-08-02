# Top 階層 (`VDRV_v2_top`) システム検証計画書

## 1. 概要 (Overview)
本ドキュメントは、VDRV_v2 トップ階層 (`VDRV_v2_top` / `VDRV_v2_core`) における HW/SW 協調シミュレーションおよびシステム全体系の検証計画を定義する。

## 2. 検証対象コンポーネント (Target Components)
* `VDRV_v2_top`: トップレベル階層（共有 DMEM SRAM, IMEM ROM, コアロジックの接続）
* `VDRV_v2_core`: コアロジック（PicoRV32 CPU, AES-DMA, Load Sequencer, UART Controller, AES Power Manager, DMEM Bus Arbiter）
* `firmware`: 実環境上で動作する C/Assembly ベアメタルファームウェア

## 3. テストシナリオ (Test Scenarios)
1. **ファームウェア起動 & メモリ初期化テスト**:
   - `imem` (8KB) への `firmware.hex` ロードとリセット解除後の PicoRV32 命令フェッチ確認。
2. **UART 経由のシーケンスプログラミング & 負荷制御テスト**:
   - UART RX ピンよりバイナリパケット（`0xAA 0x55` ヘッダ、SET_STEP/START_SEQ コマンド）をシリアル送信。
   - `uart_ctrl` によるパケットデコードと `load_sequencer` 16ステップテーブルへの登録動作検証。
3. **HW/SW 協調制御 & IR-Drop 負荷モード遷移テスト**:
   - シーケンス開始後の `aes_load_mode_en` (連続暗号化) および `cpu_load_state[1:0]` 信号の自動切り替わり。
   - PicoRV32 ファームウェアによる `LOAD_STATE` ポーリングと、高負荷（Intensive ALU ループ）/ 低負荷（NOP 待機）の協調追従動作。
4. **PD_AES電源遷移テスト**:
   - `AES_FULL` のHW-Directシーケンス開始で、Power ManagerがPD_AESをONにしてからAES負荷を許可すること。
   - シーケンス停止後、進行中処理をquiesceし、isolation後にPD_AESがOFFとなること。
   - `POWER_AWARE_SIM` でOFF中のPD_AES出力がXとなっても、AON側のisolation出力へXが漏れないこと。

## 4. 検証環境
* ツール: Icarus Verilog (`iverilog`, `vvp`)
* テストベンチ: `VDRV_v2/top/tb/tb_VDRV_v2_top.v`
