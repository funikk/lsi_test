# Load DMA Subsystem 単体検証計画書 (`blocks/load_dma_subsys`)

## 1. 検証目的 (Verification Objectives)
`load_dma_subsys` は、MAC負荷コア、CRC負荷コア、およびPRNGユニットを統括するコアモジュールである。
本検証計画では、以下の項目を単体テストベンチ（`tb/tb_load_dma_subsys.v`）により網羅的に評価し、機能妥当性とタイミング整合性を検証する。

1. MMIOスレーブレジスタに対する読み書きアクセス、PRNG初期シードロード機能、およびPRNG出力読み出し機能の健全性。
2. DMAエンジンによるDMEMからの128ビットブロック読み出し、各演算モード（MAC、CRC、MAC+CRC XOR）における正しいコア起動と結果書き込みの健全性。
3. ソフトウェア制御による有限ブロック連続負荷モード（`REG_LEN = 3`）における、正確なブロック数計数、完了ステータスセット、およびイネーブル自動クリア論理。
4. 負荷シーケンサを模擬したハードウェア直接モード（`hw_load_mode_active = 1`）における、動的ステップ遷移（MACのみ → CRCのみ → MAC+CRC同時 → IDLE）の確実な追従性とバック・トゥ・バック起動。

---

## 2. 検証項目一覧 (Test Matrix)

| テストID | テスト項目名 | 検証内容と手順 | 期待される結果 (Pass Criteria) |
| :--- | :--- | :--- | :--- |
| **TEST 1** | シード・コンフィグMMIO設定 & PRNG読み出し | 1. `REG_SEED[0..3]` へ固有値を書き込み。<br>2. `REG_CTRL[2]` (`SEED_LOAD`) をパルス発行。<br>3. `REG_PRNG_DATA[0..3]` を読み出し照合。<br>4. `REG_CFG[0..3]` へ固有値を書き込み、読み出し照合。 | 設定したシード値がPRNG出力レジスタへ正確に反映され、コンフィグレジスタがビット反転なく正常に保持・読み出し可能であること。 |
| **TEST 2A** | DMA MAC単独モード (`DMA_MODE_SEL = 00`) | 1. DMEM 0x100 に128ビットテストデータを配置。<br>2. `SRC=0x100`, `DST=0x200`, `LEN=1` を設定。<br>3. `DMA_START` を発行し、`STATUS[1]` (`DONE`) を待機。<br>4. DMEM 0x200 の書き込み結果を取得。 | 正常に完了フラグが立ち、DMEM 0x200 に非ゼロのMAC演算結果シグネチャが書き込まれること。 |
| **TEST 2B** | DMA CRC単独モード (`DMA_MODE_SEL = 01`) | 1. 同一入力データに対し `DST=0x210`, `LEN=1` を設定。<br>2. `DMA_MODE_SEL = 01` で起動し、完了待機。<br>3. DMEM 0x210 の結果を取得し MAC 結果と比較。 | 非ゼロであり、かつTEST 2A のMAC結果とは明確に異なるCRC固有シグネチャが書き込まれること。 |
| **TEST 2C** | DMA MAC+CRC XORモード (`DMA_MODE_SEL = 10`) | 1. 同一入力データに対し `DST=0x220`, `LEN=1` を設定。<br>2. `DMA_MODE_SEL = 10` で起動し、完了待機。<br>3. DMEM 0x220 の結果を取得し、TEST 2A と TEST 2B の排他的論理和と照合。 | 書き込み結果が $\text{mac\_res} \oplus \text{crc\_res}$ とビットレベルで100%一致すること。 |
| **TEST 3A** | ソフトウェア有限負荷: MAC単独 | 1. `REG_LEN = 3` を設定。<br>2. `REG_CTRL[1]` (`SW_MAC_LOAD_EN`) を1に設定。<br>3. `REG_STATUS[1]` (`DONE`) の立ち上がりを待機。<br>4. `REG_CTRL` および `REG_STATUS` を確認。 | 3ブロック（計30サイクル）実行後に完了し、`REG_CTRL[1]` が0に自動クリアされ、`DONE=1` となること。 |
| **TEST 3B** | ソフトウェア有限負荷: CRC単独 | 1. `REG_LEN = 3` を設定。<br>2. `REG_CTRL[3]` (`SW_CRC_LOAD_EN`) を1に設定。<br>3. `DONE` 待機後、レジスタ状態を確認。 | 3ブロック実行後に完了し、`REG_CTRL[3]` が0に自動クリアされ、`DONE=1` となること。 |
| **TEST 3C** | ソフトウェア有限負荷: MAC+CRC同時 | 1. `REG_LEN = 3` を設定。<br>2. `REG_CTRL[1]`, `[3]` を同時に1に設定。<br>3. 動作中のビジーステータスを確認。<br>4. `DONE` 待機後、レジスタ状態を確認。 | 動作中に `MAC_BUSY=1` かつ `CRC_BUSY=1` となり、3ブロック完了時に両方のイネーブルビットが同時に自動クリアされること。 |
| **TEST 4** | ハードウェア直接モード動的ステップ遷移 | 1. `hw_load_mode_active = 1` をアサート。<br>2. Step 0: `hw_mac_load_en=1`, `hw_crc_load_en=0` (25サイクル)<br>3. Step 1: `hw_mac_load_en=0`, `hw_crc_load_en=1` (25サイクル)<br>4. Step 2: `hw_mac_load_en=1`, `hw_crc_load_en=1` (25サイクル)<br>5. Step 3: 両イネーブルを0に落とし、完了後に `hw_load_mode_active=0`。 | 各ステップの切り替え時にコアが即座に起動し、停止時に進行中ブロックを正常完了してアイドル状態（`BUSY=0`）に復帰すること。 |

---

## 3. テストベンチ設計 (`tb/tb_load_dma_subsys.v`)

1. **クロック & リセット生成**:
   - クロック: 100MHz (周期 10ns, 5ns トグル)
   - リセット: 開始時 25ns アサート後、ネゲート
2. **DMEMモデル**:
   - 256ワード（1KB）の同期RAMモデルを内蔵。
   - `dma_valid` および `dma_wstrb` に応答し、単一サイクルハンドシェイクでリード/ライトを実行。
3. **MMIOタスク**:
   - `mmio_write(addr, data)`: `mmio_valid` アサートと `mmio_ready` ハンドシェイク。
   - `mmio_read(addr, data)`: レディ待機後にデータ取得。
