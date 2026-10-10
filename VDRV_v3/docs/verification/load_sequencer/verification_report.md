# Load Sequencer モジュール 検証レポート (VDRV_v3)

## 1. 検証結果サマリ

| 検証項目 | ツール | 結果 | 備考 |
| :--- | :--- | :---: | :--- |
| **静的解析 (Lint)** | Verilator v5.032 | **PASS** | `-Wall` でエラー・警告なし (0 warnings) |
| **事前論理検証 (Presynth)** | Yosys v0.52 | **PASS** | `proc; check -assert` でエラー・問題なし (0 problems) |
| **論理合成 (Synthesis)** | Yosys v0.52 | **PASS** | Out-of-Context 合成完了 (セル数: 3,395, メモリ未解決なし) |
| **単体機能検証 (Unit Sim)** | Icarus Verilog v12.0 / VVP | **PASS** | 全フェーズ自己判定成功 (`TEST PASSED`) |

---

## 2. 単体シミュレーション実行結果

実行コマンド: `make -C blocks/load_sequencer unit_sim`

```text
make: ディレクトリ '/home/ikuo/src/lsi_test/VDRV_v3/blocks/load_sequencer' に入ります
( iverilog -o sim/sim.vvp -f filelist.f ./tb/tb_load_sequencer.v && vvp sim/sim.vvp ) 2>&1 | tee sim/unit_sim.log
VCD info: dumpfile sim/tb_load_sequencer.vcd opened for output.
=== Phase 0: Reset State Verification ===
=== Phase 1: MMIO Programming and Readback ===
=== Phase 2: ONESHOT Run with Cycle-Accurate Verification ===
[SIM] Step 0 starting at time 565000
[SIM] Step 1 starting at time 685000
[SIM] Step 2 starting at time 765000
[SIM] Sequence completed at time 925000
=== Phase 3: Loop Mode Verification (ONESHOT=0) ===
[SIM] Checking loop wrap to Step 0 at time 1445000
=== Phase 4: Stop via MMIO (SEQ_ENABLE=0) ===
=== Phase 5: IRQ Mode Verification (IRQ_MODE=1) ===
=== Phase 6: UART cmd_set_step & UART Start/Stop ===
=== All tests completed successfully! ===
TEST PASSED
./tb/tb_load_sequencer.v:472: $finish called at 2235000 (1ps)
make: ディレクトリ '/home/ikuo/src/lsi_test/VDRV_v3/blocks/load_sequencer' から出ます
```

---

## 3. テスト項目別詳細結果

1. **TC-01 リセット動作 (Phase 0)**:
   - リセット解除直後の全出力（`running=0`, `seq_done=0`, `hw_direct_active=0`, `seq_pg_sync=0`, `cpu_irq=0`, `cur_step=0`）が規定値であることを確認。
2. **TC-02 MMIO設定とリードバック (Phase 1)**:
   - 3ステップ分の `STEP_W0`, `STEP_W1` レジスタへの設定値が正しく読み出せることを確認。
   - `SEQ_CTRL` および `SEQ_STATUS` のリードバック値の一致を確認。
   - 未定義オフセットへの読み出しで `32'h0` が返ることを確認。
3. **TC-03/04/05 ONESHOT サイクル精度実行 (Phase 2)**:
   - `TICK_DIV = 3` (1 tick = 4 サイクル) の条件下で、3つのステップを連続実行：
     - Step 0 (DURATION=2): 厳密に $3 \times 4 = 12$ サイクル継続。
     - Step 1 (DURATION=1): 厳密に $2 \times 4 = 8$ サイクル継続。
     - Step 2 (DURATION=3): 厳密に $4 \times 4 = 16$ サイクル継続。
   - 各ステップの先頭サイクル（Step 0 を含む）で `seq_pg_sync` が厳密に 1 サイクルのみパルス出力されることを確認。
   - 各ステップ期間中、`cur_profile_id`, `cur_marker`, `cur_em_ctrl`, `cur_pd_req`, `cur_step` が設定値通り出力されることを確認。
   - Step 2 終了時に `running=0`, `seq_done=1`, `hw_direct_active=0` となり、以降のサイクルでも `cur_*` の値が維持されることを確認。
4. **TC-06 ループ実行 (Phase 3)**:
   - `ONESHOT = 0` の設定で、Step 2 終了後に Step 0 へ自動ラップアラウンドすることを確認。
   - ラップアラウンド後も `running=1`, `seq_done=0` を維持し、Step 0 開始時に `seq_pg_sync` がパルス出力されることを確認。
5. **TC-07 MMIO 停止機能 (Phase 4)**:
   - 実行中に `SEQ_ENABLE=0` を書き込むことで、即座に `running=0` に遷移し停止することを確認。
6. **TC-08 IRQ モード動作 (Phase 5)**:
   - `IRQ_MODE = 1` 設定時、シーケンス実行中も `hw_direct_active=0` が維持されることを確認。
   - Step 0 $\rightarrow$ Step 1、Step 1 $\rightarrow$ Step 2、および Step 2 完了時の各遷移タイミングで、`cpu_irq` が厳密に 1 サイクルパルス出力されることを確認。
7. **TC-09/10 UART インターフェース動作 (Phase 6)**:
   - `cmd_set_step` コマンドにより、対象ステップの `DURATION` と `PROFILE_ID` のみが更新され、既存の `MARKER`, `EM_CTRL`, `PD_REQ` が非破壊で保持されることを確認。
   - `cmd_start_seq` による自律シーケンス開始（ステップ0から開始）、および `cmd_stop_seq` による停止が正常に動作することを確認。

---

## 4. 結論

`load_sequencer` モジュールは、VDRV_v3 モジュール間インターフェース仕様書（第6節）に完全準拠しており、要求されるサイクル精度、マルチステップ制御、同期・割り込み生成、および UART/MMIO デュアルアクセス機能のすべてが正常に動作することを検証完了した。
