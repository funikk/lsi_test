# MAC Load Core 単体検証レポート (`blocks/mac_load_core`)

## 1. 検証結果サマリ (Summary)

*   **検証ステータス**: **PASS (全項目合格)**
*   **対象ブロック**: `blocks/mac_load_core`
*   **検証環境**:
    *   Linter: Verilator 5.032
    *   Simulator: Icarus Verilog 12.0 / VVP
    *   Logic Synthesis: Yosys 0.52
*   **論理合成セル数**: **10,819 cells** (目標範囲: 9,500 〜 11,500 cells を達成)

---

## 2. 実行結果詳細

### 2.1 静的解析 (Lint & Pre-synthesis Check)

コマンド:
```bash
make -C blocks/mac_load_core lint presynth_check
```

- **Verilator Lint (`sim/lint.log`)**:
  - `--lint-only -Wall` をパス。エラーおよび警告 **0件**。
- **Yosys Pre-synthesis Check (`syn/presynth_check.log`)**:
  - `proc; check -assert` をパス。ラッチの意図しない推論やアサーション違反 **0件**。

### 2.2 単体機能シミュレーション (`sim/unit_sim.log`)

コマンド:
```bash
make -C blocks/mac_load_core unit_sim
```

実行ログ:
```text
===============================================================
[TB START] Verification of mac_load_core unit started
===============================================================
[TEST 1] Checking Reset State...
[PASS] Test 1: Reset behavior verified (ready=1, data_out=0).

[TEST 2] Single Block Execution & Determinism Test...
  Single Block Run 1: Latency = 10 cycles (expected 10)
  Output Signature  : 0x20b7c003d709f344d8c353d676a21ebf
  Single Block Run 2 (Determinism): Output = 0x20b7c003d709f344d8c353d676a21ebf
[PASS] Test 2: Single block execution verified (exact 10 cycles, deterministic non-zero signature).

[TEST 3] Continuous Back-to-Back Multi-Block Execution...
  Block A Result: 0x78534417cf4f5efcf2d3adcd1b1c1cde (cycles: 10)
  Block B Result: 0xb68dd58ce3667e93f1b6f56bbf1ed81b (cycles: 10)
  Block C Result: 0xad28dc71a5a47c4f630b22cc246f940d (cycles: 10)
[PASS] Test 3: Continuous back-to-back execution verified with distinct signatures.

===============================================================
[TB SUCCESS] ALL mac_load_core UNIT TESTS PASSED
===============================================================
```

- **Test 1 (リセット検証)**:
  - リセット時 `ready == 1'b1`, `data_out == 128'h0` を確認。
- **Test 2 (単一ブロック実行・再現性)**:
  - 10クロックサイクルの厳密な実行レイテンシを観測。
  - 同一入力（`0x0123...` / `0xa5a5...`）に対して複数回実行し、同一シグネチャ `0x20b7c003d709f344d8c353d676a21ebf` が完全に一致することを確認。
- **Test 3 (連続バック・トゥ・バック実行)**:
  - ブロック完了と同時に次ブロックを投入する連続処理において、パイプラインの停止やデッドロックなく各 10サイクルで完走。
  - 各ブロック（Block A, B, C）から衝突のない固有シグネチャが生成されることを確認。

---

## 3. 論理合成統計 (Synthesis Statistics)

コマンド:
```bash
make -C blocks/mac_load_core syn
```

合成結果統計（Yosys `synth -top mac_load_core; stat` より抜粋）:

```text
=== design hierarchy ===

   mac_load_core                     1
     mac_array (ROWS=5, COLS=4)      1
       mac_unit (DATA_W=8, ACC_W=16) 20

   Number of wires:               9298
   Number of wire bits:          15246
   Number of public wires:         287
   Number of public wire bits:    4150
   Number of ports:                196
   Number of port bits:           2003
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:              10819
     $_ANDNOT_                    2561
     $_AND_                       1002
     $_DFFE_PN0P_                 1056
     $_DFFE_PN1P_                    1
     $_DFF_PN0_                      1
     $_MUX_                        257
     $_NAND_                       720
     $_NOR_                        200
     $_NOT_                        248
     $_ORNOT_                      252
     $_OR_                        1010
     $_XNOR_                       730
     $_XOR_                        2781
```

- **総セル数**: **10,819 cells**
- **セル数評価**: 目標値（9,500 〜 11,500 セル、中心値 10,000 セル）に対して 10,819 セル（+8.2%）と極めて良好な規模設計を達成した。

---

## 4. 判定 (Conclusion)
すべての静的解析、単体シミュレーション（10サイクルハンドシェイク、決定論的再現性、連続実行）、および論理合成セル数要件を満たしており、システム統合レイヤへの組み込み準備が完了したと判定する。
