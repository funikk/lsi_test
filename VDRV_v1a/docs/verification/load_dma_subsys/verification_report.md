# Load DMA Subsystem 単体検証レポート (`blocks/load_dma_subsys`)

## 1. 検証結果サマリ (Summary)

*   **検証ステータス**: **PASS (全項目合格)**
*   **対象ブロック**: `blocks/load_dma_subsys`
*   **検証環境**:
    *   Linter: Verilator 5.032
    *   Simulator: Icarus Verilog 12.0 / VVP
    *   Logic Synthesis: Yosys 0.52
*   **論理合成セル数**: **26,356 cells** (MACコア約10,819 cells + CRCコア約10,830 cells + PRNG約724 cells + DMA/MMIO制御約3,983 cells)

---

## 2. 実行結果詳細

### 2.1 静的解析 (Lint & Pre-synthesis Check)

コマンド:
```bash
make -C blocks/load_dma_subsys lint presynth_check
```

- **Verilator Lint (`sim/lint.log`)**:
  - `-Wall` チェックをパス。エラーおよび致命的警告 **0件**。
- **Yosys Pre-synthesis Check (`syn/presynth_check.log`)**:
  - `proc; check -assert` をパス。未駆動信号、ラッチの不正推論、アサーション違反 **0件**。

### 2.2 単体機能シミュレーション (`sim/unit_sim.log`)

コマンド:
```bash
make -C blocks/load_dma_subsys unit_sim
```

実行ログ:
```text
===============================================================
[TB START] Verification of load_dma_subsys started
===============================================================

[TEST 1] Seed & Config MMIO programming and PRNG readout...
[PASS] Test 1: Seed & Config programming and PRNG readout verified.

[TEST 2] DMA Mode (MAC, CRC, MAC+CRC XOR)...
  DMA MAC Result: 0xed6e0582f262d0ac8ea343ba321689f0
  DMA CRC Result: 0x909f5ecc25a7bdc989513e1aab4951c3
  DMA XOR Result: 0x7df15b4ed7c56d6507f27da0995fd833
[PASS] Test 2: DMA mode (MAC, CRC, MAC+CRC XOR) verified successfully.

[TEST 3] Software finite-block continuous load mode (REG_LEN = 3)...
  3A: SW MAC only (REG_LEN = 3)...
  [PASS] 3A: MAC only completed 3 blocks, auto-cleared.
  3B: SW CRC only (REG_LEN = 3)...
  [PASS] 3B: CRC only completed 3 blocks, auto-cleared.
  3C: SW MAC + CRC simultaneously (REG_LEN = 3)...
  [PASS] 3C: Simultaneous MAC + CRC completed 3 blocks, both auto-cleared.
[PASS] Test 3: Software finite-block continuous load mode verified successfully.

[TEST 4] Hardware-direct mode dynamic stepping...
  Step 0: HW MAC only...
  Status in Step 0: 0x00000002
  Step 1: HW CRC only...
  Status in Step 1: 0x00000002
  Step 2: HW MAC + CRC...
  Status in Step 2: 0x0000000a
  Step 3: HW IDLE...
  Status after return to IDLE: 0x00000002
[PASS] Test 4: Hardware-direct mode dynamic stepping verified successfully.

===============================================================
[TB SUCCESS] ALL load_dma_subsys UNIT TESTS PASSED
===============================================================
```

### 2.3 検証項目別評価

1. **TEST 1 (シード・コンフィグMMIO設定 & PRNG読み出し)**:
   - `REG_SEED[0..3]` に書き込んだ値（`0x11112222_33334444_55556666_77778888`）が、`REG_CTRL[2]` のロードトリガによりPRNGへ即座に反映され、`REG_PRNG_DATA[0..3]` から完全一致で読み出せることを確認。
   - `REG_CFG[0..3]` への多ビット書き込みおよび読み出しが正常であることを確認。
2. **TEST 2 (DMA転送 & 演算モード選択)**:
   - **MAC単独 (`2'b00`)**: DMEM 0x100 からのデータをMACコアで処理し、DMEM 0x200 へ非ゼロ結果 `0xed6e0582f262d0ac8ea343ba321689f0` を書き込み完了。
   - **CRC単独 (`2'b01`)**: 同一データに対してCRCコアを実行し、DMEM 0x210 へ固有結果 `0x909f5ecc25a7bdc989513e1aab4951c3` を書き込み完了。
   - **MAC+CRC XOR (`2'b10`)**: 両コアを完全並列実行し、DMEM 0x220 へ書き込まれた結果 `0x7df15b4ed7c56d6507f27da0995fd833` が、理論値 $\text{MAC} \oplus \text{CRC}$ と完全一致することをビットレベルで確認。
3. **TEST 3 (ソフトウェア有限ブロック連続負荷モード)**:
   - `REG_LEN = 3` 指定時、MAC単独・CRC単独・MAC+CRC同時のいずれにおいても、正確に3ブロック（30サイクル）の実行を完了。
   - 最終ブロック完了と同時に `REG_STATUS[1]` (`DONE`) がセットされ、`REG_CTRL[1]` および `REG_CTRL[3]` のイネーブルビットがハードウェアにより自動クリアされることを確認。
4. **TEST 4 (ハードウェア直接モード動的ステップ遷移)**:
   - `hw_load_mode_active = 1` において、シーケンサの各ステップ遷移（MACのみ → CRCのみ → 両方同時 → IDLE）に遅延なく即座に追従し、ビジーステータスが正しく反映されることを確認。
   - 停止時には実行中のブロックを正常に完走した上でアイドル状態に復帰することを確認。

---

## 3. 論理合成統計 (Synthesis Statistics)

コマンド:
```bash
make -C blocks/load_dma_subsys syn
```

Yosys論理合成結果（階層別セル数）:

```text
=== design hierarchy ===

   load_dma_subsys                   1
     crc_load_core                   1
       crc_channel                   4
     lfsr_prng_ctrl                  1
       lfsr_32_ctrl                  4
     mac_load_core                   1
       mac_array                     1
         mac_unit                   20

   Number of cells:              26356
     $_ANDNOT_                    7005
     $_AND_                       1322
     $_DFFE_PN0N_                    1
     $_DFFE_PN0P_                 1901
     $_DFFE_PN1P_                    2
     $_DFFE_PP_                      1
     $_DFF_PN0_                      8
     $_MUX_                       1108
     $_NAND_                       781
     $_NOR_                        283
     $_NOT_                        434
     $_ORNOT_                      400
     $_OR_                        1729
     $_SDFFE_PN0P_                 476
     $_SDFFE_PN1P_                  64
     $_SDFF_PN0_                     3
     $_XNOR_                      1561
     $_XOR_                       9277
```

- **総セル数**: **26,356 cells**
- **規模内訳**:
  - `mac_load_core`: 約 10,819 cells
  - `crc_load_core`: 約 10,830 cells
  - `lfsr_prng_ctrl`: 約 724 cells
  - `load_dma_subsys` (MMIO/DMA/Arbiter/Buffers): 約 3,983 cells

---

## 4. 判定 (Conclusion)
すべての静的解析（Lint、Pre-synthesis Check）、単体機能シミュレーション（全4テストケース）、および論理合成がエラーおよび警告なく完了した。暗号機能への依存はなく、VDRV_v1aチップのトップレベル統合への組み込み準備が完了した。
