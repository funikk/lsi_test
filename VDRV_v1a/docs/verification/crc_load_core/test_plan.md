# 検証計画書: crc_load_core

## 1. 検証目的

本計画書は、電源ノイズ・IR-Dropストレステストベンチ用モジュール `crc_load_core` の機能健全性、ハンドシェイクタイミング、感度、および物理合成親和性を保証するための単体検証計画を定める。

---

## 2. 検証ツール・実行環境

| ツール区分 | 使用ツール | バージョン / オプション | 実行目的 |
| :--- | :--- | :--- | :--- |
| シミュレータ | Icarus Verilog (iverilog) | v12.0 (`-g2012`) | テストベンチ機能検証・波形ダンプ |
| 静的リンター | Verilator | v5.032 (`--lint-only -Wall`) | RTLコーディング規則・未接続・未駆動検出 |
| 構文・論理事前検査 | Yosys | v0.52 (`proc; check -assert`) | ラッチ・プロセス競合・組合せループ検出 |
| 論理合成・面積評価 | Yosys | v0.52 (`synth -top crc_load_core; stat`) | 総セル数評価 (9,500〜11,500セル目標) |

---

## 3. テスト項目一覧 (Test Matrix)

| テストID | テスト項目名 | 検証シナリオ | 期待値・合否基準 |
| :---: | :--- | :--- | :--- |
| **TC_01** | 非同期リセット動作検証 | `rst_n` を Low にアサートし、内部レジスタと出力ポートの初期状態を確認後、リセットを解除。 | リセット中および解除直後に `ready == 1'b1`, `data_out == 128'h0` であること。 |
| **TC_02** | 単一ブロック演算と実行サイクル検証 | `ready == 1` 時に `start` パルス (1サイクル) を印加。`ready` が Low に立ち下がり、再び High に復帰するまでのクロック数を計測。 | `ready` が正確に10サイクル (`ITER_CYCLES`) 間 Low を維持し、High 復帰時に `data_out != 128'h0` であること。 |
| **TC_03** | 決定論的動作の再現性検証 | 同一の `data_in` および `cfg_in` ベクトルを用いて独立した2回の演算を実行し、出力を比較。 | 2回の演算結果 `data_out` が完全一致すること。 |
| **TC_04** | 入力データ感度検証 (`data_in`) | `cfg_in` を固定し、`data_in` の最下位ビット (1ビット) を反転させたベクトルを実行。 | 出力 `data_out` が TC_02 の結果から大きく変化 (全ビットに変化が波及) すること。 |
| **TC_05** | 設定ベクトル感度検証 (`cfg_in`) | `data_in` を固定し、`cfg_in` の最下位ビット (1ビット) を反転させたベクトルを実行。 | 出力 `data_out` が TC_02 および TC_04 の結果のいずれとも異なること。 |
| **TC_06** | バックトゥバック連続実行検証 | 1ブロック目の完了 (`ready == 1'b1`) 直後のクロックサイクルで直ちに2ブロック目の `start` を印加。 | バブルサイクルなく直ちに2ブロック目の実行に入り、10サイクル後に有効な結果が出力されること。 |

---

## 4. 実行コマンド手順

単体テスト環境は `blocks/crc_load_core/` 配下の Makefile により完全自動化される。

```bash
# 1. 静的リント検査
make -C blocks/crc_load_core lint

# 2. 合成前AST・品質検査
make -C blocks/crc_load_core presynth_check

# 3. 単体シミュレーション実行
make -C blocks/crc_load_core unit_sim

# 4. Out-of-Context 合成実行
make -C blocks/crc_load_core syn

# 5. セル規模計測 (約10,000セル目標確認)
cd blocks/crc_load_core && yosys -p "read_verilog rtl/crc_channel.v rtl/crc_load_core.v; synth -top crc_load_core; stat"
```
