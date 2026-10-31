# MAC Load Core テスト計画書 (`blocks/mac_load_core`)

## 1. 概要 (Overview)
本ドキュメントは、VDRV_v1a プロジェクトの `mac_load_core` ブロックに対する単体機能検証計画を定義する。
本ブロックは、10サイクルの厳密なハンドシェイクタイミング、決定論的（Deterministic）な出力再現性、および高スイッチング負荷生成能力を検証対象とする。

---

## 2. 検証対象ファイル (Verification Scope)
- RTLソース:
  - `blocks/mac_load_core/rtl/mac_unit.v`
  - `blocks/mac_load_core/rtl/mac_array.v`
  - `blocks/mac_load_core/rtl/mac_load_core.v`
- テストベンチ:
  - `blocks/mac_load_core/tb/tb_mac_load_core.v`

---

## 3. 検証項目 (Test Items)

### 3.1 静的解析および事前品質チェック
1. **Verilator Lint (`make lint`)**:
   - `--lint-only -Wall` オプションによる完全警告ゼロ（Zero Warnings）の達成。
   - 未駆動ピン、幅ミスマッチ、Timescale齟齬、多重駆動等の潜在的バグの排除。
2. **Yosys プリシンセシス・チェック (`make presynth_check`)**:
   - `proc; check -assert` によるAST変換可能性およびアサーション違反のないことの確認。

### 3.2 単体機能検証 (`make unit_sim`)
1. **Test 1: リセット状態検証 (Reset Behavior Check)**
   - 非同期リセットアサート中およびリセット解除直後において、`ready == 1'b1` かつ `data_out == 128'b0` であることを確認。
   - アイドル状態でクロックが進行しても `ready` が 1 を維持し続けることを確認。
2. **Test 2: 単一ブロック実行レイテンシおよび決定論的再現性 (Single Block Latency & Determinism)**
   - `start` パルス入力後、`ready` が直ちに `0` にデアサートされることを確認。
   - `ready` が `0` を維持する期間が、パラメータ `ITER_CYCLES`（デフォルト 10サイクル）と厳密に一致することをサイクルカウントによって確認。
   - 完了時の `data_out` が非ゼロであり、同一の `data_in` / `cfg_in` 入力パターンに対して複数回実行した際に 100% 同一の出力シグネチャを再現できることを確認。
3. **Test 3: 連続バック・トゥ・バック実行 (Continuous Back-to-Back Execution)**
   - 1ブロックの処理完了（`ready == 1`）と同時に次ブロックの `start` パルスおよび新規データを投入し、ウェイトサイクルを挟まない連続実行を検証。
   - 複数の異なる入力データパターン（Block A, Block B, Block C）に対して、それぞれ 10サイクルのレイテンシで処理が完了することを確認。
   - 生成される各出力シグネチャが全て非ゼロであり、かつ互いに重複しない独立した値（No Signature Collision）となることを確認。

### 3.3 論理合成規模検証 (`make syn`)
1. **Yosys 論理合成 (`synth -top mac_load_core`)**:
   - 目標セル数範囲: **9,500 〜 11,500 セル** （約10kセル）。
   - 5行×4列シストリックアレイ構造における最適化結果の確認。
