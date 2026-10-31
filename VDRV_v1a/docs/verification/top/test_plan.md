# VDRV_v1a トップ階層 (`VDRV_v1a_top`) システム検証計画書 (Top Verification Plan)

## 1. 概要 (Overview)

本ドキュメントは、`VDRV_v1a` トップ階層 (`VDRV_v1a_top` / `VDRV_v1a_core`) における HW/SW 協調シミュレーション、DMA 機能検証、および UART シーケンサ負荷制御の検証計画を定義します。

---

## 2. 検証対象コンポーネント (Target Components)

* **`VDRV_v1a_top`**: トップレベル統合ラッパー（`imem` 8KB ROM, `dmem` 512B SRAM, `VDRV_v1a_core`）
* **`VDRV_v1a_core`**: PnR 対象コアロジック
  - `picorv32`: RISC-V 32-bit CPU コア
  - `load_dma_subsys`: 負荷生成 & DMA サブシステム
  - `mac_load_core`: 5x4 シストリック MAC アレイ
  - `crc_load_core`: 4 チャネル並列 CRC & RS ミキサ
  - `lfsr_prng_ctrl`: 128-bit LFSR 疑似乱数生成器
  - `load_sequencer`: 16 ステップ・ハイブリッド負荷シーケンサ
  - `uart_ctrl`: 115200 bps UART コントローラ & パケットパーサー
  - DMEM バス調退器 (DMA 優先調停)
* **`firmware`**: RV32I ベアメタル C/Assembly ファームウェア (`firmware.hex`)

---

## 3. テスト項目および合否判定基準

| 項目番号 | 検証項目 | テスト内容 | 合否判定基準 |
| :---: | :--- | :--- | :--- |
| **TC-01** | ファームウェア起動 & 自己診断 | リセット解除後、CPU が `imem` から命令フェッチを開始し、初期設定と DMA 動作を実行する | `DMEM[63]` に `0xDEADBEEF` が書き込まれること |
| **TC-02** | MAC DMA 演算・転送機能 | MAC モード (`DMA_MODE_SEL = 00`) で `DMEM[0..3]` から読み出し演算後、`DMEM[8..11]` へ書き戻す | `DMEM[8..11]` が非ゼロであり、期待演算結果と一致すること |
| **TC-03** | CRC DMA 演算・転送機能 | CRC モード (`DMA_MODE_SEL = 01`) で `DMEM[0..3]` から読み出し演算後、`DMEM[12..15]` へ書き戻す | `DMEM[12..15]` が非ゼロであり、MAC 出力と明確に異なること (`DMEM[8..11] != DMEM[12..15]`) |
| **TC-04** | 連続負荷モード動作 | 有限ブロック負荷 (`LEN = 3`) および無限負荷 (`LEN = 0`) を実行後、正常復帰する | ステータスレジスタの `DONE` フラグが正常にアサートされること |
| **TC-05** | UART シーケンス設定 | UART 経由で 4 ステップ（MAC_ONLY, CRC_ONLY, MAC+CRC, ALL_FULL）のパケットをシリアル送信 | パケットパーサーがパケットを正しくデコードし、シーケンサテーブルに反映されること |
| **TC-06** | シーケンサ実行 & 状態遷移 | `CMD_START_SEQ` 送信後、各ステップの負荷イネーブル信号とステートが順次遷移する | `mac_load_mode_en`, `crc_load_mode_en`, `cpu_load_state[2:0]` が `3'b001` -> `3'b010` -> `3'b011` -> `3'b111` へ遷移すること |

---

## 4. 検証環境

* **シミュレータ**: Icarus Verilog (`iverilog`, `vvp`)
* **テストベンチ**: `VDRV_v1a/top/tb/tb_VDRV_v1a_top.v`
* **実行コマンド**: `make top_sim` または `make -C top rtl_sim`
