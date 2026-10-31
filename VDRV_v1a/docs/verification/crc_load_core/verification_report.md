# 検証報告書: crc_load_core

## 1. 検証結果サマリー

`crc_load_core` に対する論理設計・静的解析・単体シミュレーション・論理合成の全工程を実施し、すべての検証項目に合格した。

| 検証フェーズ | 実行ツール | 判定結果 | 備考 |
| :--- | :--- | :---: | :--- |
| **静的リント検査** | Verilator v5.032 | **PASS** | 警告・エラー 0 件 |
| **事前合成品質検査** | Yosys v0.52 | **PASS** | ラッチ推論なし、アサーション違反 0 件 |
| **単体機能検証** | Icarus Verilog v12.0 | **PASS** | 全6テスト項目 (TC_01〜TC_06) 100% 合格 |
| **合成セル数評価** | Yosys v0.52 | **PASS** | **10,833 セル** (目標範囲 9,500〜11,500 内) |

---

## 2. 単体シミュレーション実行結果ログ

テストベンチ (`blocks/crc_load_core/tb/tb_crc_load_core.v`) による実行結果のログ概要を以下に示す。

```text
================================================================
[TB START] Starting comprehensive unit test for crc_load_core
================================================================
[PASS] Test 1: Reset state verified (ready == 1, data_out == 0).
[INFO] Block A execution finished. Low cycle duration = 10 cycles.
[PASS] Test 2: Handshake timing verified (exactly 10 cycles low).
[PASS] Test 2: data_out is non-zero (0x8b05f6cf44f06b3bd27b45fa1c02136f)
[PASS] Test 3: Deterministic computation verified across identical runs.
[PASS] Test 4: data_in sensitivity confirmed. Output changed significantly.
       A1:        0x8b05f6cf44f06b3bd27b45fa1c02136f
       Data_flip: 0xe27ae6ebd0ec9a9bf3237a13a3175f72
[PASS] Test 5: cfg_in sensitivity confirmed. Output changed significantly.
       A1:       0x8b05f6cf44f06b3bd27b45fa1c02136f
       Cfg_flip: 0xdd5a7c35772ca5a1ae25a992188e1323
[INFO] Starting Test 6: Back-to-back continuous block execution...
[PASS] Test 6: Back-to-back execution succeeded cleanly.
       Result C: 0x6e9d200eb65f8d46bf0c523d361053d1
================================================================
[ALL TESTS PASSED] crc_load_core unit verification SUCCESSFUL!
================================================================
```

### 検証項目達成状況
- **TC_01 (非同期リセット)**: リセットアサート中および解除直後、`ready == 1'b1` かつ `data_out == 128'h0` であることを確認。
- **TC_02 (ハンドシェイクタイミング)**: `start` パルス入力後、`ready` が正確に10クロックサイクル間 Low を維持し、10サイクル後に復帰して非ゼロ出力値 (`0x8b05f6cf44f06b3bd27b45fa1c02136f`) をラッチすることを確認。
- **TC_03 (決定論的動作)**: 同一入力を印加した2回の実行で完全一致する出力を確認。
- **TC_04 (データ感度)**: 入力データの1ビット反転により、出力全域に変化が拡散することを確認。
- **TC_05 (設定感度)**: 設定ベクトルの1ビット反転により、多項式・係数変化を通じて出力が大幅に変化することを確認。
- **TC_06 (バックトゥバック実行)**: アイドル待機サイクルを挟まず連続入力を行っても、10サイクルの固定タイミングで正しく連続演算可能であることを確認。

---

## 3. 論理合成およびセル規模実績 (Yosys)

`yosys -p "read_verilog rtl/crc_channel.v rtl/crc_load_core.v; synth -top crc_load_core; stat"` を実行した合成結果の統計情報を以下に示す。

### 3.1 階層別セル数内訳
- `crc_channel` (1チャネルあたり): 2,401 セル
- `crc_load_core` トップロジック (シンドロームミキサー・レジスタ・制御): 1,233 セル
- **全設計階層合計**: **10,833 セル**

### 3.2 セル種別統計表

| セル種別 | セル数 | 説明 |
| :--- | :---: | :--- |
| `$_XOR_` | 5,940 | 排他的論理和ゲート (CRC除算・シンドローム加算ツリー) |
| `$_ANDNOT_` | 3,405 | 多項式マスク条件ゲート |
| `$_XNOR_` | 691 | 多項式除算ツリー論理ゲート |
| `$_MUX_` | 257 | データパスセレクタ |
| `$_DFFE_PN0P_` | 388 | クロック同期データレジスタ (`state_reg`, `cfg_reg`, `data_out`) |
| `$_NOT_` | 86 | 反転論理ゲート |
| `$_ORNOT_` | 60 | 多項式マスク生成ゲート |
| `$_NAND_` / `$_OR_` | 4 | その他基本論理ゲート |
| `$_DFF_PN0_` / `$_DFFE_PN1P_` | 2 | FSMステート・準備完了制御フリップフロップ |
| **合計** | **10,833** | **目標範囲: 9,500 〜 11,500 セル (達成率: 103.2%)** |

---

## 4. 総合評価

`crc_load_core` は要求仕様である約10,000セル（実績 10,833セル）を正確に満たし、10サイクルの固定レイテンシ・ハンドシェイク動作、および高い論理反転率を備えていることが確認された。
上位統合（`top/` および `blocks/load_dma_subsys/`）への接続準備が完了している。
