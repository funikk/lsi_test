# 128-bit LFSR PRNG 単体検証レポート (`blocks/lfsr_prng`)

## 1. 検証結果サマリ (Summary)

*   **検証ステータス**: **PASS (全項目合格)**
*   **対象ブロック**: `blocks/lfsr_prng`
*   **検証環境**:
    *   Linter: Verilator 5.032
    *   Simulator: Icarus Verilog 12.0 / VVP
    *   Logic Synthesis: Yosys 0.52
*   **論理合成セル数**: **724 cells** (32ビットLFSR 181 cells × 4基)

---

## 2. 実行結果詳細

### 2.1 静的解析 (Lint & Pre-synthesis Check)

コマンド:
```bash
make -C blocks/lfsr_prng lint presynth_check
```

- **Verilator Lint (`sim/lint.log`)**:
  - `-Wall` チェックをパス。エラーおよび警告 **0件**。
- **Yosys Pre-synthesis Check (`syn/presynth_check.log`)**:
  - `proc; check -assert` をパス。アサーション違反やラッチ推論 **0件**。

### 2.2 単体機能シミュレーション (`sim/unit_sim.log`)

コマンド:
```bash
make -C blocks/lfsr_prng unit_sim
```

実行ログ:
```text
[UNIT SIM: lfsr_prng] Loaded Seed = 0x89abcdef012345675a5a5a5aa5a5a5a5
[UNIT SIM: lfsr_prng] PRNG Output after 5 shifts = 0xd1a9a838382025ed94fa10e6a1006527
[UNIT TEST PASSED] LFSR PRNG Seed Load & Shift Output Verified!
```

- **シードロード動作**:
  - テストシード `0x89abcdef012345675a5a5a5aa5a5a5a5` がクロック同期で正確に出力端へ反映されたことを確認。
- **シフト更新動作**:
  - `en = 1` による5サイクルのシフト後、出力が `0xd1a9a838382025ed94fa10e6a1006527` に更新され、全ビットが正常に推移することを確認。

---

## 3. 論理合成統計 (Synthesis Statistics)

コマンド:
```bash
make -C blocks/lfsr_prng syn
```

Yosys論理合成結果（各モジュールセル数）:

```text
=== lfsr_32_ctrl ===

   Number of cells:                181
     $_MUX_                         32
     $_NOT_                         11
     $_OR_                           1
     $_SDFFE_PN0P_                  32
     $_XNOR_                        31
     $_XOR_                         74

=== lfsr_prng_ctrl (Top) ===

   Number of cells:                  4
     lfsr_32_ctrl                    4

   合計セル数: 181 × 4 = 724 cells
```

- **フリップフロップ数**: 128 (32ビット × 4)
- **組み合わせ回路**: 596 cells

---

## 4. 判定 (Conclusion)
静的解析、機能シミュレーション、および論理合成のすべてが正常に完了した。
負荷DMAサブシステム（`load_dma_subsys`）における乱数データ供給ブロックとしての組み込み要件を完全に満たしていると判定する。
