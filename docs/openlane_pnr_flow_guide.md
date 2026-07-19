# OpenLaneによる新規回路の配置配線 (PnR) 実行手順ガイド

このガイドでは、作成した新しいVerilog RTL設計を、**OpenLane (Docker版)** と **sky130 PDK** を使用して配置配線 (PnR) し、最終的なLSIレイアウトデータ (GDSII) を生成する手順を説明します。

---

## 1. ディレクトリの準備

OpenLaneで新しい回路を処理するには、まず `openlane/designs/` ディレクトリの下に、デザイン名と同じ名前のフォルダを作成します。

```bash
# 例: デザイン名が "my_awesome_design" の場合 (リポジトリのルートで実行)
mkdir -p openlane/designs/my_awesome_design
```

---

## 2. 設定ファイル (`config.json`) の作成

作成したフォルダの直下に `config.json` というファイルを作成し、合成や配置配線のルールを定義します。

### 設定ファイルのテンプレート例
`openlane/designs/my_awesome_design/config.json` を作成し、以下を記述します。

```json
{
    "DESIGN_NAME": "my_awesome_design",
    "VERILOG_FILES": [
        "dir::../../../my_awesome_design/rtl/my_submodule.v",
        "dir::../../../my_awesome_design/rtl/my_awesome_design.v"
    ],
    "CLOCK_PERIOD": 10.0,
    "CLOCK_PORT": "clk",
    "CLOCK_NET": "ref::$CLOCK_PORT",
    "pdk::sky130*": {
        "FP_CORE_UTIL": 40,
        "PL_TARGET_DENSITY": 0.45,
        "SYNTH_MAX_FANOUT": 20
    }
}
```

### 主要パラメータの解説
| パラメータ名 | 設定値の例 | 説明 |
| :--- | :--- | :--- |
| `DESIGN_NAME` | `"my_awesome_design"` | トップモジュールの名前（Verilogの `module` 名と一致させること）。 |
| `VERILOG_FILES` | `["dir::../../../<デザイン名>/rtl/*.v"]` | 入力となるVerilogソースファイルのパスの配列。`dir::` 接頭辞を使うことで、この `config.json` の場所からの相対パスを指定できます。 |
| `CLOCK_PERIOD` | `10.0` | ターゲットとするクロック周期（単位: ナノ秒）。10.0は 100 MHz に相当します。 |
| `CLOCK_PORT` | `"clk"` | クロック入力ポートのポート名。 |
| `FP_CORE_UTIL` | `40` | コア領域に対するスタンダードセルの配置密度の初期ターゲット（単位: ％）。通常は40〜50%から始めます。 |
| `PL_TARGET_DENSITY`| `0.45` | 配置（Placement）時の目標密度。`FP_CORE_UTIL` より少し高め（0.05〜0.1プラス）に設定します。 |
| `SYNTH_MAX_FANOUT` | `20` | 合成時の最大ファンアウト制約。 |

---

## 3. フローの実行

準備ができたら、以下の Docker コマンドをホストマシンのターミナルで実行してフローを走らせます。

```bash
# リポジトリのルート (lsi_test/) で実行する場合の例
export PDK_ROOT=$(pwd)/pdks
docker run --rm \
  -v $(pwd)/openlane:/openlane \
  -v $(pwd)/openlane/designs:/openlane/install \
  -v $(pwd):$(pwd) \
  -v $PDK_ROOT:$PDK_ROOT \
  -e PDK_ROOT=$PDK_ROOT \
  -e PDK=sky130A \
  ghcr.io/the-openroad-project/openlane:ff5509f65b17bfa4068d5336495ab1718987ff69-amd64 \
  ./flow.tcl -design my_awesome_design -tag my_run_tag
```
*※ `my_awesome_design` と `my_run_tag` は各自のデザイン名と任意の実行タグ名に変更してください。*

---

## 4. 実行結果と成果物の確認

フローが無事完了すると、端末に `[SUCCESS]: Flow complete.` と表示されます。結果は以下のディレクトリに出力されます。

```text
openlane/designs/my_awesome_design/runs/my_run_tag/
```

### 主な確認用レポートファイル
*   **製造性サマリー (DRC/LVS結果)**: `reports/manufacturability.rpt`
    *   MagicによるDRC違反数 (`Magic DRC violations`) が **0** であること、および `Design is LVS clean.` と表示されていることを確認します。
*   **メトリクスサマリー (面積・セル数・タイミングなど)**: `reports/metrics.csv`
    *   スラック、トランジション違反、セルの総数などが1行のCSVとして集約されています。
*   **タイミングレポートの詳細**: `reports/signoff/31-rcx_sta.summary.rpt`
    *   Setup（最大遅延）および Hold（最小遅延）のスラック（余剰時間）が正の値（Positive）であることを確認します。負の値（Negative）の場合はタイミング違反が発生しています。

### 主な出力データ
*   **GDSIIレイアウトデータ**: `results/final/gds/my_awesome_design.gds` (物理マスクデータ)
*   **配置配線DEFデータ**: `results/final/def/my_awesome_design.def` (物理セル・配線の配置データ)
*   **ゲートレベルVerilog**: `results/final/verilog/my_awesome_design.v` (電源配線込みの最終ネットリスト)

---

## 5. タイミングエラーやDRC/LVSエラーへの対処法

*   **Setupタイミング違反 (スラックが負の値) が出た場合**:
    1.  `config.json` の `CLOCK_PERIOD` を少し緩めて（値を大きくして）再実行します。
    2.  あるいは、RTL自体のクリティカルパスにパイプラインレジスタを追加して細分化します。
*   **DRC違反（配線ショートなど）が出た場合**:
    *   セル配置が過密になっている可能性があります。`config.json` の `FP_CORE_UTIL` を `35` や `30` などに下げて、配置スペースに余裕を持たせて再実行してください。

---

## 6. 異なる条件での並行実行と結果の比較

同じ回路に対して、クロック周波数や配置密度などの条件を変えてPnRを実行し、それぞれの結果（レイアウトやレポート）を上書きせずに保存して比較することが可能です。

### 方法1: 実行タグ (`-tag`) を分ける

OpenLaneを実行する際、コマンド末尾の `-tag <実行名>` オプションに異なる名前を指定します。

*   **条件A (例: 100MHz動作のターゲット)**:
    `config.json` で `"CLOCK_PERIOD": 10.0` に設定し、以下で実行：
    ```bash
    # 実行コマンドの末尾 ... ./flow.tcl -design my_awesome_design -tag run_100MHz
    ```
    結果は `runs/run_100MHz/` に保存されます。

*   **条件B (例: 125MHz動作を狙うターゲット)**:
    `config.json` で `"CLOCK_PERIOD": 8.0` に変更し、以下で実行：
    ```bash
    # 実行コマンドの末尾 ... ./flow.tcl -design my_awesome_design -tag run_125MHz
    ```
    結果は `runs/run_125MHz/` に保存されます。

これにより、既存の `runs/run_100MHz/` を消去することなく、新旧の結果が並存します。

### 方法2: 設定ファイル自体を複数用意する (`-config_file`)

いちいち `config.json` を書き換えるのが面倒な場合、異なる設定ファイルを複数用意して明示的に指定することもできます。

1.  `config_100MHz.json` と `config_125MHz.json` の2つのファイルをデザインディレクトリ内に作成します。
2.  実行時に `-config_file` オプションで読み込むファイルを切り替えます。
    ```bash
    # 125MHz設定ファイルを指定して実行する例
    # ... ./flow.tcl -design my_awesome_design -tag run_125MHz -config_file designs/my_awesome_design/config_125MHz.json
    ```

### 結果の比較方法
それぞれのフォルダに生成された `reports/metrics.csv` を並べて確認するか、KLayoutなどでそれぞれの `results/final/gds/` 内のGDSファイルを読み込んで見比べることで、条件による面積や配線密度の変化、タイミングスラックの推移を視覚的・数値的に比較できます。
