# System Control (`sys_ctrl`) テスト計画書および検証結果

## 1. 検証概要
`sys_ctrl` ブロックにおける `scenario_sel` の2段FF同期化およびリードバック、`STATUS`/`MARKER`/`SIG_OUT` による出力端子駆動、`CYCLE` フリーランカウンタのインクリメント動作を検証する。

## 2. 検証項目
1. **静的検証 (Lint)**
   - Verilator (`-Wall`) による静的解析（警告0件）。
2. **前合成チェック (Presynth Check)**
   - Yosys による `proc; check -assert` 実行。意図しないラッチ生成や組合せループがないこと。
3. **機能検証 (Unit Sim)**
   - 初期リセット時、各出力ピンが 0 に初期化されること。
   - `scenario_sel` の非同期遷移が2段FFを経て2〜3クロック後に `SCENARIO` レジスタから正確にリードバックできること。
   - `STATUS` への書き込み値（`scenario_done`, `sig_ok`）が出力ピンに直ちに反映され、リードバックできること。
   - `MARKER` への書き込み値が出力ピン `sw_marker` に反映され、リードバックできること。
   - `SIG_OUT` への書き込み値が出力ピン `sig_out` に反映され、リードバックできること。
   - `CYCLE` カウンタがクロック毎にインクリメントされていること。

## 3. テストベンチ構成
- テストベンチファイル: `tb/tb_sys_ctrl.v`
- 自己判定機能: 全項目の一致を確認後、`TEST PASSED` を出力して `$finish(0)`。エラー時は `TEST FAILED` を出力して `$finish(1)`。
- ウォッチドッグタイマ: 50µsでタイムアウト。

## 4. 検証結果
- **Verilator Lint**: PASSED (警告0件)
- **Pre-synthesis Check**: PASSED (0 problems reported)
- **単体シミュレーション (unit_sim)**: PASSED (`TEST PASSED`)
