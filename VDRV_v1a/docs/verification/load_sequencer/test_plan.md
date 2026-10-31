# Load Sequencer テスト計画

## 1. 概要
本ドキュメントは、VDRV_v1aにおける負荷シーケンサ（`load_sequencer`）の機能検証計画を記述する。
3ビット負荷状態（`{cpu_en, crc_en, mac_en}`）に基づく自律シーケンス生成、UARTおよびMMIOインターフェースを介したプログラミング、デュアルモード（HW-DirectモードおよびCPU-IRQモード）の動作信頼性を検証する。

## 2. 検証対象
- 対象モジュール: `load_sequencer` (相対パス: `blocks/load_sequencer/rtl/load_sequencer.v`)
- テストベンチ: `tb_load_sequencer` (相対パス: `blocks/load_sequencer/tb/tb_load_sequencer.v`)

## 3. 検証項目

### 3.1 リセットおよび初期状態検証
- 非同期リセット（`rst_n = 0`）時、内部タイマー、シーケンスメモリ、およびすべての出力信号（`mac_load_mode_en`, `crc_load_mode_en`, `hw_direct_active`, `cpu_load_state`, `cpu_irq`）が0に初期化されること。

### 3.2 プログラミングおよびレジスタアクセス
1. **UARTステッププログラミング**:
   - `cmd_set_step` 信号を用いて、Step 0〜3へ3ビット負荷状態および継続時間Tickを書き込み。
2. **MMIOステップレジスタ読み出し (オフセット 0x10〜0x1C)**:
   - UARTで書き込んだデータが `STEP_REG[0..3]` から正確に読み出せること（フォーマット: `{13'h0, state[2:0], duration[15:0]}`）。
3. **MMIOステップレジスタ書き込み・読み出し (オフセット 0x20)**:
   - MMIO経由で `STEP_REG[4]` に直接書き込みを行い、同アドレスからのリードバック値が一致すること。
4. **MMIO制御・状態レジスタアクセス**:
   - `SEQ_CTRL` (0x00): 設定値（`total_steps`, `seq_enable`, `irq_mode`）の反映およびリードバック。
   - `SEQ_STATUS` (0x04): 動作状態、現在ステップ、残りTick、負荷状態のリアルタイム読み出し。
   - `REG_LOAD_STATE` (0x08): `cpu_load_state[2:0]` の読み出し。

### 3.3 HW-Directモード動作検証 (irq_mode = 0)
1. **HW-Direct活性化**:
   - シーケンス実行中、`hw_direct_active` 信号が常時高レベル (1) となること。
2. **各負荷コア出力遷移**:
   - Step 0 (MAC_ONLY `3'b001`): `mac_load_mode_en = 1`, `crc_load_mode_en = 0`, `cpu_load_state = 3'b001`
   - Step 1 (CRC_ONLY `3'b010`): `mac_load_mode_en = 0`, `crc_load_mode_en = 1`, `cpu_load_state = 3'b010`
   - Step 2 (MAC_CRC  `3'b011`): `mac_load_mode_en = 1`, `crc_load_mode_en = 1`, `cpu_load_state = 3'b011`
   - Step 3 (ALL_FULL `3'b111`): `mac_load_mode_en = 1`, `crc_load_mode_en = 1`, `cpu_load_state = 3'b111`
3. **割り込み不発生**:
   - HW-Directモード中には `cpu_irq` パルスが一切発生しないこと。
4. **MMIO停止処理**:
   - `seq_enable = 0` 書き込みによりシーケンスが直ちに停止し、全負荷イネーブル信号が0にクリアされること。

### 3.4 IRQモード動作およびUART制御検証 (irq_mode = 1)
1. **HW-Direct非活性**:
   - シーケンス動作中であっても `hw_direct_active` は低レベル (0) を維持すること。
2. **UART開始・停止**:
   - `cmd_start_seq` パルスによりシーケンスが開始し、`cmd_stop_seq` パルスにより停止すること。
3. **ステップ満了割り込み発生**:
   - ステップのTickカウント満了・次ステップ遷移時に `cpu_irq` 信号が1クロック幅でアサートされること。

## 4. 実行手順
`blocks/load_sequencer/` ディレクトリにて以下のコマンドを実行する。
```bash
make lint            # Verilator による静的チェック
make presynth_check  # Yosys による事前論理チェック
make unit_sim        # Icarus Verilog による自動検証シミュレーション
make syn             # Yosys による論理合成チェック
```
