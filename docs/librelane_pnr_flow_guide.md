# LibreLane PnR フロー実行ガイド (新規回路モジュール実装手順)

本ガイドでは、新しい Verilog / SystemVerilog 回路モジュールを **LibreLane** (旧 OpenLane 2) に組み込み、RTL論理合成から配置配線 (PnR)、タイミング解析 (STA)、DRC/LVS 検証、GDSII レイアウト出力までを自動実行するための標準手順を解説します。

---

## 1. ディレクトリ構成ルール

新しい回路モジュールを追加する場合、プロジェクトルート (`lsi_test`) の配下に以下のディレクトリ構成を作成します。

```text
lsi_test/
├── docs/
│   └── librelane_pnr_flow_guide.md          # 本ガイド
├── tools/
│   ├── report_qor_phases.py                 # QoR集計スクリプト
│   └── open_viewer.sh                       # GUIビューア起動スクリプト
├── librelane/                               # LibreLane 本体 (Nix flake / uv環境)
├── shell.nix / .envrc                       # プロジェクトルート Nix 環境定義
├── pdks/                                    # sky130A PDK ディレクトリ
├── librelane_designs/                       # LibreLane用デザイン設定フォルダ
│   └── <新規モジュール名>/                   # 例: my_fifo_top
│       └── config.json                      # 設計設定ファイル
└── <新規サブプロジェクト>/                   # RTLリソースフォルダ
    └── rtl/
        └── <新規モジュール名>.v
```

*※注意: 実行結果のパーミッション問題を回避するため、設定ファイル `config.json` はユーザー書き込み権限のある `librelane_designs/<新規モジュール名>/` 配下に配置します。*

---

## 2. ステップ 1: 設計設定ファイル (`config.json`) の作成

新規モジュール用の設定ファイルを `librelane_designs/<新規モジュール名>/config.json` として作成します。

### 設定ファイル例 (`librelane_designs/my_fifo_top/config.json`):

```json
{
    "DESIGN_NAME": "my_fifo_top",
    "VERILOG_FILES": [
        "dir::../../my_fifo_test/rtl/my_fifo_top.v"
    ],
    "CLOCK_PERIOD": 10.0,
    "CLOCK_PORT": "clk",
    "CLOCK_NET": "ref::$CLOCK_PORT",
    "STD_CELL_LIBRARY": "sky130_fd_sc_hd",
    "STD_CELL_LIBRARY_OPT": "sky130_fd_sc_hd",
    "pdk::sky130*": {
        "FP_CORE_UTIL": 40,
        "PL_TARGET_DENSITY_PCT": 45,
        "MAX_FANOUT_CONSTRAINT": 20
    }
}
```

### 主要パラメータの説明:
* **`DESIGN_NAME`**: RTLのトップレベルモジュール名。
* **`VERILOG_FILES`**: RTLソースファイルのリスト。相対パスの指定には **`dir::`** 接頭辞を使用します（`config.json` が置かれた場所からの相対パス）。
* **`CLOCK_PERIOD`**: ターゲットクロック周期 (単位: ns)。例: `10.0` (100MHz), `8.0` (125MHz)。
* **`CLOCK_PORT`**: クロック信号のポート名。
* **`STD_CELL_LIBRARY`**: 使用する標準セルライブラリ。
  * `sky130_fd_sc_hd`: 高密度・低電力ライブラリ (High Density)
  * `sky130_fd_sc_hs`: 高速動作ライブラリ (High Speed)
* **`FP_CORE_UTIL`**: コア領域に対するセル配置密度のターゲット利用率 (%)。
* **`PL_TARGET_DENSITY_PCT`**: 配置最適化エンジンのターゲット密度 (%)。

---

## 3. ステップ 2: プレ合成・RTL品質の高速チェック (`presynth_check`)

PnR (配置配線) 実行前に、RTLに潜在する多重ドライバ違反や合成不能セル（例: 変数非同期リセットによる `$_ALDFFE_*` の生成）を **1 秒未満で事前抽出** するため、プレ合成チェックを実行します。

```bash
# 対象サブプロジェクトディレクトリにて実行 (例: cpu_aes_prng_test)
cd cpu_aes_prng_test
make presynth_check
```

### プレ合成チェックで事前に防止できる主な問題:
1. **多重ドライバ違反 (Multiple Conflicting Drivers)**:
   同一の `reg` が複数の `always` ブロックから駆動されている設計ミス。
2. **非標準セルの生成 (Unmapped Cells / ALDFFE / Latch)**:
   非同期リセット条件 `if (!rst_n)` 下で定数ではなく入力変数を代入 (`out <= seed_in`) し、PDKに存在しない非同期ロードフリップフロップが抽出されるミス。
3. **フローティング配線・未接続ポート (Floating Wires)**.

---

## 4. ステップ 3: LibreLane PnR フローの実行 (`tools/run_pnr.py`)

統合実行スクリプト `tools/run_pnr.py` を使用することで、標準実行だけでなくクロック周波数の変更・セルライブラリ切り替え・スイープ実行・途中ステップからの再開を簡単に行えます。
*(※ Nix 環境外で実行された場合でも、`tools/run_pnr.py` が自動的に `nix develop ./librelane` を検出・起動して Yosys 0.62 / OpenROAD 環境へ引き継ぎます)*

```bash
# ① 標準実行 (デフォルト 100MHz / sky130_fd_sc_hd / 上書き実行)
python3 tools/run_pnr.py <新規モジュール名>

# ② クロック周波数を 125MHz (8.0ns) に変更して実行 (タグは自動的に run_125MHz_hd に決定)
python3 tools/run_pnr.py <新規モジュール名> --clk-period 8.0

# ③ 高速セルライブラリ (hs) を指定して実行
python3 tools/run_pnr.py <新規モジュール名> --std-cell sky130_fd_sc_hs

# ④ 複数周波数のスイープ連続実行 (10.0ns, 8.0ns, 6.67ns)
python3 tools/run_pnr.py <新規モジュール名> --sweep-clk 10.0,8.0,6.67

# ⑤ デバッグ用：指定ステップから再開
python3 tools/run_pnr.py <新規モジュール名> --from-step openroad-detailedplacement
```

---

## 4. ステップ 3: QoR（品質指標）および実行時間の集計

PnR完了後、集計スクリプトを実行して各フェーズ（Synth / Place / CTS / Route）におけるセル面積・インスタンス数・Setup/Hold スラック・違反パス数・実行時間を表示します。

```bash
# プロジェクトルートにて実行
./tools/report_qor_phases.py librelane_designs/<新規モジュール名>/runs/run_100MHz
```

### 出力例:
```markdown
## LibreLane 各設計フェーズにおける QoR・実行時間 集計結果
- **ターゲット実行フォルダ**: `librelane_designs/my_fifo_top/runs/run_100MHz`
- **対象コーナー**: `nom_tt_025C_1v80`
- **フロー全ステップ合計実行時間**: `12.4` 分

| 設計フェーズ | インスタンス数 | スタンダードセル面積 | Setup 最悪スラック | Setup NPV | Hold 最悪スラック | Hold NPV | ステップ所要時間 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 1. 論理合成 (Synth) | 1,250 | 18,450.00 µm² | -0.45 ns | 12 | +0.12 ns | 0 | 5.2 秒 |
| 2. 配置 (Place) | 1,410 | 19,200.00 µm² | -1.20 ns | 18 | -2.50 ns | 24 | 4.8 秒 |
| 3. クロックツリー (CTS) | 1,520 | 21,100.00 µm² | +0.85 ns | 0 | +0.22 ns | 0 | 6.1 秒 |
| 4. 配線後 (Route) | 3,840 | 21,150.00 µm² | +0.62 ns | 0 | +0.25 ns | 0 | 45.0 秒 |
```

---

## 5. ステップ 4: レイアウトの確認 (GUI Viewers)

生成された GDSII や配置配線レイアウト（DEF）を GUI で対話的に確認・デバッグするには、ビューア起動ヘルパースクリプトを使用します。

```bash
# 事前にホスト側で X11 画面接続を許可
xhost +

# OpenROAD GUI を起動 (配置配線・タイミングパス・ヒートマップの確認)
./tools/open_viewer.sh <モジュール名>           # 例: ./tools/open_viewer.sh counter
./tools/open_viewer.sh openroad <モジュール名>  # 例: ./tools/open_viewer.sh openroad counter

# KLayout GUI を起動 (GDSII マスクレイアウトの閲覧)
./tools/open_viewer.sh <モジュール名> klayout   # 例: ./tools/open_viewer.sh counter klayout

# Magic GUI を起動 (DRC 違反個所の確認)
./tools/open_viewer.sh magic <モジュール名>    # 例: ./tools/open_viewer.sh magic counter
```

---

## 6. ベストプラクティス・トラブルシューティング

1. **ポータビリティの維持 (絶対パスの非使用)**:
   ドキュメントやスクリプト内にはホストの絶対パス（`/home/username/...` など）を直接記述せず、必ず `$(pwd)` や相対パス（`dir::`）を使用してください。
2. **Timing Violation (スラック負値) への対処**:
   * タイミングがクローズしない場合、`config.json` の `CLOCK_PERIOD` を緩めるか、ライブラリを `sky130_fd_sc_hs`（高速ライブラリ）に切り替えて再実行します。
3. **成果物 (GDSII/DEF) の場所**:
   すべての最終成果物は `librelane_designs/<新規モジュール名>/runs/<run_tag>/final/` 配下に保存されます。
   * GDSII: `final/gds/<新規モジュール名>.gds`
   * 2Dレンダリング画像: `final/render/<新規モジュール名>.png`

---

## 7. SDC タイミング制約と Reset Synchronizer の記述ルール

OpenROAD / LibreLane 環境においてカスタム SDC (`constraint.sdc`) を記述する際の重要ポイントです。

1. **OpenROAD SDC 互換性 (`set_dont_touch` の回避)**:
   * OpenSTA (OpenROAD SDC パーサー) では `set_dont_touch` コマンドが認識されず構文エラーとなります。不要な `set_dont_touch` コマンドは SDC から除外してください。
2. **`set_max_delay` による物理近接自動誘導**:
   * 2 段 FF（リセット同期化回路等）のセル同士を物理的に隣接・近接配置させたい場合、セル間の遅延上限を極小化する制約を与えます。
   ```tcl
   set_max_delay 2.0 -from [get_cells -hierarchical *u_reset_sync*u_dff1*] \
                     -to   [get_cells -hierarchical *u_reset_sync*u_dff2*]
   ```
3. **非同期パス除外とエスケープ階層文字のマッチング**:
   * 非同期リセットピンには `set_false_path -from [get_ports {rst_n}]` を設定します。
   * Yosys 合成後ネットリストでは階層区切りがドット（`.`）やエスケープ記法に変換されるため、`-from` / `-to` のセル名指定には `*u_reset_sync*u_dff1*` パターンを使用します。

