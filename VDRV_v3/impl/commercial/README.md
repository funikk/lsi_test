# 商用40nm PDK インプリメンテーション・解析実行ガイド

本ディレクトリ（`impl/commercial/`）には、VDRV_v3 を商用40nm PDK環境（TSMC 40nm 等）へ移行し、物理設計（PnR）および EM/IR ドロップ解析ツール（Ansys RedHawk-SC、Cadence Voltus、Synopsys PrimePower/RedHawk 等）で評価・テストするための雛形スクリプトと制約ファイルが格納されています。

---

## 1. 格納ファイル構成

- `cell_map.md` : 商用40nm PDKセルへの差し替え・マッピング仕様書
- `vdrv_v3.upf` : IEEE 1801 UPF 2.0/3.0 電源意図記述（2段階パワースイッチ、Isolation、PST）
- `vdrv_v3.sdc` : 商用40nm 向け STA タイミング制約（200MHz, クロックゲーティング, EM例外）
- `README.md` : 本ガイド

---

## 2. インプリメンテーション手順

### ステップ 1: ラッパーセルの差し替え
`common/rtl/` に配置されている以下の3つのラッパーモジュールを、商用40nm PDKのセルに差し替えます（詳細は `cell_map.md` を参照）：
1. `vdrv_icg.v` $\rightarrow$ ライブラリの ICG セル（例: `CKLNQD4BWP40`）
2. `vdrv_sram_wrap.v` $\rightarrow$ メモリコンパイラ生成の 1-Port SRAM マクロ（1024x32）
3. `vdrv_iso_and.v` $\rightarrow$ ライブラリの Isolation セル（または UPF 自動挿入に任せてバイパス）

### ステップ 2: 論理合成 (Synopsys Design Compiler / Cadence Genus)
- **Top RTL**: `top/rtl/VDRV_v3_top.v`
- **SDC 読み込み**: `read_sdc vdrv_v3.sdc`
- **UPF 読み込み**: `load_upf vdrv_v3.upf` (LP合成フロー)
- **オプション**:
  - `compile_ultra -gate_clock` (ICGの自動挿入・マッピング)
  - `set_dont_touch` on `em_stress` のファンアウトネット

### ステップ 3: 配置配線 (Synopsys IC Compiler II / Cadence Innovus)
1. **フロアプラン**:
   - ダイサイズ設定（例: 2x2タイル + 端列 = 約 0.8mm x 0.8mm 〜 1.2mm x 1.2mm）。
   - 各電源ドメイン `PD_ROW0`、`PD_ROW1` の電圧領域（Voltage Area）を作成。
   - `em_stress` の `u_tx` と `u_rx` を対角に配置（Floorplan Region 制約）。
2. **パワースイッチ配置**:
   - 各 PD_ROW の境界に沿って Daisy Chain 接続で Header/Footer スイッチセルを挿入。
   - `sw_trickle_en` / `sw_trickle_ack` および `sw_main_en` / `sw_main_ack` のピンへ結線。
3. **パワーグリッド設計**:
   - トップ電源メッシュ（VDD, VSS）を最上層メタル（例: M8, M9）に強固に配置。
   - スイッチド電源レール（VDD_ROW0, VDD_ROW1）を中間層（M4〜M6）および標準セルレールに接続。
4. **CTS & 配線**:
   - CTS 実行後、詳細配線（NanoRoute / Zroute）を実行。
   - GDSII および DEF/SPEF を出力。

---

## 3. EM/IR ドロップ解析の実行

本テストベンチは、外部入力ピン `scenario_sel[3:0]` を切り替えるだけで、様々な電源ストレスシナリオを自己励起（Self-Stimulating）します。

### 3.1 主な解析シナリオと評価項目
- **シナリオ 1 (`ALL_ON_SYNC`)**:
  - 全タイル（AES + MACアレイ + LFSR）が 100% 活性率で同期動作。
  - **最大動的IRドロップ (Peak Dynamic IR Drop)** および vectorless 解析ツールの精度検証に最適。
- **シナリオ 2 (`STEP_LOAD`)**:
  - 全タイル クロックゲートOFF $\rightarrow$ 一斉解除（100%）。
  - 急峻な電流変化による **$L \cdot \frac{di}{dt}$ 電圧サージ・リンギング** を評価。
- **シナリオ 8 (`PWRUP_SAFE`) vs シナリオ 9 (`PWRUP_UNSAFE`)**:
  - 段階投入（Trickle $\rightarrow$ Main, Stagger=8）と一斉投入（Unsafe Mode）の突入電流（Inrush Current）を直接比較。
- **シナリオ 11 (`EM_STRESS`)**:
  - 広幅交互反転バス（32-bit）＋ 64-fanout 非バッファ網を高周波駆動。
  - **信号線EM・ビア電流密度違反 (Jmax / Blech limit)** の検出感度を評価。

### 3.2 マーカーピン (`marker`) を用いた解析区間切り出し
- `marker[1:0]` ピンが `01`、`10`、`11` に遷移するタイミングをトリガーとして、VCD/FSDB波形の解析対象時間枠（Time Window）を自動切り出し可能です。
