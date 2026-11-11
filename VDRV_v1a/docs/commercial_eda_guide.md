# VDRV_v1a 商用EDAツール実行ガイド (Synopsys VCS & Fusion Compiler)

本ドキュメントでは、`VDRV_v1a` 設計を Synopsys 社の商用EDAツール（**VCS** および **Fusion Compiler**）で実行・検証・インプリメンテーションするための手順と仕様を解説します。

---

## 1. ディレクトリ構成

商用EDAツール用の資産は、既存のオープンソースEDA資産と明確に分離された独立ディレクトリに配置されています。

```text
VDRV_v1a/
├── sim_vcs/                       # Synopsys VCS シミュレーション環境
│   ├── Makefile                   # VCSコンパイル・実行・Verdi連携
│   ├── vcs_filelist.f             # VCS用ファイルリスト（+incdir+, +define+）
│   └── run_vcs.sh                 # スタンドアロン実行シェルスクリプト
│
├── fc/                            # Synopsys Fusion Compiler (RTL-to-GDSII)
│   ├── Makefile                   # FCバッチ・GUI実行Makefile
│   ├── fc_env.sh                  # PDK・ライブラリ環境変数設定スクリプト
│   ├── inputs/                    # 入力制約
│   │   ├── constraint.sdc         # 100MHz FC用SDC
│   │   └── pin_constraints.tcl    # ダイ四辺ピン配置Tcl
│   ├── scripts/                   # モジュール化された実行Tclスクリプト
│   │   ├── 00_common_setup.tcl    # 共通変数・マルチスレッド設定
│   │   ├── 01_lib_setup.tcl       # NDM/PDKライブラリ設定（PDK抽象化レイヤ）
│   │   ├── 02_read_design.tcl     # RTL読み込み (analyze & elaborate)
│   │   ├── 03_constraints.tcl     # SDC制約読み込み・タイミングチェック
│   │   ├── 04_compile_synth.tcl   # 論理合成 (compile_fusion)
│   │   ├── 05_floorplan.tcl       # フロアプラン、PGメッシュ、ピン配置
│   │   ├── 06_place_opt.tcl       # スタンダードセル配置 & 最適化
│   │   ├── 07_cts_opt.tcl         # クロックツリー合成 (CTS)
│   │   ├── 08_route_opt.tcl       # 詳細配線 & ポスト配線最適化
│   │   ├── 09_signoff_export.tcl  # STA解析、QoR出力、GDS/DEF/Netlist/SPEF出力
│   │   └── run_all.tcl            # フルステップ実行マスターTcl
│   ├── reports/                   # 各ステップのレポート出力先
│   └── outputs/                   # GDSII, DEF, Netlist, SPEF出力先
```

---

## 2. Synopsys VCS によるシミュレーション (RTL & Gate-Level)

### 2.1 主な特徴
- **高速シミュレーション**: 64ビットネイティブコンパイル (`-full64`)
- **波形フォーマット対応**: Verdiで高速デバッグが可能な FSDB 出力（`+define+DUMP_FSDB`）および従来の VCD 出力に対応。
- **ファームウェア自動探索**: `+define+FIRMWARE_HEX` により、実行カレントディレクトリに依存せず `firmware.hex` を正しくロード。
- **ゲートレベルシミュレーション (GLS)**:
  - 合成後・PnR後のゲートレベルネットリスト（デフォルト: `fc/outputs/VDRV_v1a_core.v`）を差し替えて実行。
  - **ゼロ遅延機能検証 (Zero-delay GLS)**: `+nospecify +notimingcheck +delay_mode_zero` により高速に機能等価性を確認。
  - **SDFタイミングシミュレーション (Timing GLS)**: `-negdelay +neg_tchk -sdf ...` により、実際のセル遅延・配線遅延を考慮したセットアップ/ホールド検証。
  - **X伝搬解析オプション**: `-xprop=tmerge` による未初期化レジスタや不定値伝搬の厳密検証。

### 2.2 実行コマンド

#### RTLシミュレーション
```bash
# VDRV_v1a ルートディレクトリから実行
make vcs_sim

# または sim_vcs/ ディレクトリに移動して詳細オプション指定
cd sim_vcs
make sim                       # FSDB出力でコンパイル＆実行
make sim WAVE_FORMAT=VCD       # VCD出力で実行
make sim COV=1                 # コードカバレッジ有効化

# Verdi GUI の起動
make verdi
```

#### ゲートレベルシミュレーション (GLS)
```bash
# VDRV_v1a ルートディレクトリから実行 (デフォルト: ゼロ遅延GLS)
make vcs_gls_sim

# または sim_vcs/ ディレクトリに移動して詳細オプション指定
cd sim_vcs

# 1. ゼロ遅延機能GLS (Zero-Delay)
make gls_sim GLS_NETLIST=../fc/outputs/VDRV_v1a_core.v CELL_LIB=/path/to/cells.v

# 2. SDFタイミング付きGLS (Timing Annotated GLS)
make gls_sim TIMING=1 \
             GLS_NETLIST=../fc/outputs/VDRV_v1a_core.v \
             SDF_FILE=../fc/outputs/VDRV_v1a_core.sdf \
             CELL_LIB=/path/to/cells.v

# 3. GLS波形を Verdi で確認
make gls_verdi
```

---

## 3. Synopsys Fusion Compiler による物理設計 (RTL-to-GDSII)

### 3.1 環境設定 (`fc_env.sh`)
商用Foundry PDK（TSMC, GF, SkyWater, SAED32等）へのポータビリティを確保するため、環境変数を設定して実行します。

```bash
cd fc
# 必要に応じて fc_env.sh を編集して PDK の NDM パス等を指定
source fc_env.sh
```

設定可能な主な環境変数：
- `FC_PDK_ROOT`: PDKのルートディレクトリ
- `FC_NDM_LIBS`: スタンダードセルおよびマクロの NDM (New Data Model) ライブラリパス一覧
- `FC_TECH_FILE`: テクノロジファイル
- `FC_TLUPLUS_MAX` / `FC_TLUPLUS_MIN`: 寄生容量抽出用 TLUPlus モデル
- `FC_NUM_CORES`: マルチスレッド実行コア数 (デフォルト: 8)

### 3.2 実行コマンド

```bash
# VDRV_v1a ルートディレクトリから実行
make fc_all                    # 全フローを一括実行
make fc_synth                  # 論理合成のみ実行
make fc_gui                    # Fusion Compiler GUI 起動

# または fc/ ディレクトリから実行
cd fc
make all                       # run_all.tcl による一括実行
make synth                     # 論理合成 (00..04)
make floorplan                 # 合成 + フロアプラン (00..05)
make place                     # 配置まで (00..06)
make cts                       # CTSまで (00..07)
make route                     # 配線まで (00..08)
make signoff                   # サインオフレポート & 成果物出力
make gui                       # fc_shell -gui 起動
make clean                     # ワークファイル・レポートのクリーンアップ
```

### 3.3 生成される成果物 (`fc/outputs/`)
- `VDRV_v1a_core.v`: ゲートレベル Verilog ネットリスト (GLS用)
- `VDRV_v1a_core.pg.v`: 電源端子付き Verilog ネットリスト (LVS/IR-Drop用)
- `VDRV_v1a_core.def`: 配置配線済みレイアウトデータ (DEF 5.8)
- `VDRV_v1a_core.spef`: 寄生容量・抵抗データ (STA/PrimePower/RedHawk用)
- `VDRV_v1a_core.gds`: レイヤーマップ指定時の最終テープアウトデータ (GDSII)

---

## 4. IR-Drop / 電圧降下解析ツールとの連携

本環境で生成される `DEF`, `SPEF`, `Verilog Netlist` は、Synopsys PrimePower や Ansys RedHawk などの IR-drop 解析ツールにそのまま入力可能な標準フォーマットです。
`fc/scripts/05_floorplan.tcl` 内の `create_pg_mesh_pattern` を編集することで、電源グリッドのピッチや幅、メタル層を変更し、IR-drop耐性の比較実験を行うことができます。
