# OpenLane から LibreLane への移行ガイド (OpenLane 1 vs LibreLane)

本ドキュメントでは、オープンソースのASIC物理設計フローツールである **OpenLane 1** と、その正式な後継プロジェクトである **LibreLane（旧 OpenLane 2）** の特徴・利点・欠点を比較し、既存の設計資産を LibreLane へ移行するための手順を解説します。

---

## 1. 背景と概要

* **OpenLane 1 (従来版)**: Efabless社を中心に開発された、Yosys, OpenROAD, Magic, KLayout などを統合してRTLからGDSIIまでを自動生成するTclベースの標準物理設計フロー。
* **LibreLane (後継版)**: Efabless社の開発体制変更に伴い、FOSSi Foundation 主導のコミュニティ主導プロジェクトとして移管・再設計された次世代のオープンソースASICフロー。「OpenLane 2」として開発されていた完全Pythonベースのコードベースが、混同を避けるため **LibreLane** に改名されました。

---

## 2. 利点・欠点の比較 (OpenLane 1 vs. LibreLane)

| 評価項目 | OpenLane 1 (従来版) | LibreLane (後継・新アーキテクチャ) |
| :--- | :--- | :--- |
| **アーキテクチャ** | Tclスクリプト主体の密結合構造 | **完全Pythonベースのモジュール設計** |
| **拡張性・カスタマイズ性** | Tclフックによる限定的な拡張。構成の変更が難解。 | **Pythonのクラス定義で任意のStepを追加・差替可能** |
| **設定ファイルの検証** | 実行時にTclエラーが発生して初めて発覚 | **Pydantic等によるスキーマ検証**（起動時に型・キーチェック） |
| **再現性 (Hermeticity)** | 中間ステートの再現が困難な場合がある | **状態管理の厳密化**（特定ステップからの再実行・逆戻りが容易） |
| **入力フォーマット** | JSON, Tcl | **JSON, YAML (`config.yaml`), Tcl (上位互換)** |
| **情報の豊富さ** | 長年の歴史がありネット上の記事・事例が豊富 | 比較的新しいため旧バージョン情報との混同に注意が必要 |
| **対話型モード** | `flow.tcl -interactive` をサポート | Tcl対話モードは廃止（Python APIでの制御に移行） |

---

## 3. LibreLane への移行手順

### Step 1: 実行環境のセットアップ
LibreLane は Python パッケージとしても提供されているため、Docker に頼らずとも `pip` で簡単にインストール可能です。

```bash
# Python パッケージとしてインストール
pip install librelane

# バージョン確認
librelane --version
```
*※Dockerコンテナ形式での実行（`ghcr.io/librelane/librelane`）も引き続きサポートされています。*

---

### Step 2: 設定ファイル (`config.json`) の互換性と修正
LibreLane は OpenLane 1 の `config.json` と約99%の互換性を保持するように設計されています。基本的にはそのまま読み込み可能ですが、以下の変更点に注意してください。

1. **推奨形式**:
   非構造的な Tcl 形式ではなく、**JSON** または **YAML (`config.yaml`)** への移行が推奨されます。
2. **非推奨変数・名前変更への対応**:
   * `SYNTH_MAX_FANOUT` → `MAX_FANOUT_CONSTRAINT` に変更。
   * 相対パスの指定に `dir::` 接頭辞を使用（LibreLaneでも引き続き有効）。

#### LibreLane 用の `config.json` 例:
```json
{
    "DESIGN_NAME": "aes_prng_top",
    "VERILOG_FILES": [
        "dir::../../../aes_prng_test/rtl/aes_sbox.v",
        "dir::../../../aes_prng_test/rtl/aes_core.v",
        "dir::../../../aes_prng_test/rtl/lfsr_prng.v",
        "dir::../../../aes_prng_test/rtl/aes_prng_top.v"
    ],
    "CLOCK_PERIOD": 8.0,
    "CLOCK_PORT": "clk",
    "CLOCK_NET": "ref::$CLOCK_PORT",
    "STD_CELL_LIBRARY": "sky130_fd_sc_hs",
    "STD_CELL_LIBRARY_OPT": "sky130_fd_sc_hs",
    "pdk::sky130*": {
        "FP_CORE_UTIL": 40,
        "PL_TARGET_DENSITY": 0.45,
        "MAX_FANOUT_CONSTRAINT": 20
    }
}
```

---

### Step 3: フロー実行コマンドの切り替え

OpenLane 1 では `./flow.tcl` コマンドを使用していましが、LibreLane では `librelane` コマンドまたは Python モジュールとして実行します。

#### OpenLane 1 の実行コマンド（従来）:
```bash
docker run --rm -v $(pwd):$(pwd) ... ./flow.tcl -design aes_prng_top -tag run_125MHz_hs -config_file designs/aes_prng_top/config_125MHz_hs.json
```

#### LibreLane の実行コマンド（移行後）:
```bash
# ローカルPython環境で実行する場合
librelane --pdk sky130A --run-tag run_125MHz_hs openlane/designs/aes_prng_top/config_125MHz_hs.json

# Dockerコンテナ経由で実行する場合
docker run --rm \
  -v $(pwd):$(pwd) \
  -e PDK_ROOT=$(pwd)/pdks \
  ghcr.io/librelane/librelane:latest \
  librelane --pdk sky130A --run-tag run_125MHz_hs openlane/designs/aes_prng_top/config_125MHz_hs.json
```

---

### Step 4: Python スクリプトによるカスタムステップの記述

OpenLane 1 では Tcl フック（`HOOK_DEFINITIONS`）を用いていた独自処理を、LibreLane では Python のクラスとして綺麗にモジュール化できます。

```python
from librelane.steps import Step

@Step.factory("my_custom_checker")
class MyCustomChecker(Step):
    id = "MyCompany.CustomChecker"
    name = "Custom Layout Quality Checker"

    def run(self, state, in_file, **kwargs):
        # 独自のパース・検証処理
        self.logger.info("Custom validation passed!")
        return state, {}
```

---

## 4. 今後の推奨方針

* **現在の環境 (`lsi_test`) の扱い**:
  現在 `lsi_test` に構築されている OpenLane 1 + Docker + sky130A の環境は、完全に検証済みであり、安定した物理設計・QoR比較（100MHz vs 125MHz, HD vs HS）が可能です。
* **新規開発・自動化への適用**:
  今後の新規回路設計や、CI/CDパイプラインへの組み込み、Pythonスクリプトによるフローの自動制御を行いたい場合は、モジュール性とエラーメッセージの視認性に優れる **LibreLane** への段階的な移行を推奨します。

---

## 5. LibreLane 用ヘルパースクリプト

本プロジェクトには、LibreLane での設計・検証を円滑に行うためのスクリプトが用意されています：

1. **QoRフェーズ別自動集計スクリプト** (`tools/report_librelane_qor_phases.py`):
   ```bash
   ./tools/report_librelane_qor_phases.py librelane_designs/aes_prng_top/runs/run_librelane
   ```
2. **ビューア簡単起動スクリプト** (`tools/open_librelane_viewer.sh`):
   ```bash
   # OpenROAD GUI を起動
   ./tools/open_librelane_viewer.sh openroad

   # KLayout GUI を起動
   ./tools/open_librelane_viewer.sh klayout

   # Magic GUI を起動
   ./tools/open_librelane_viewer.sh magic
   ```
