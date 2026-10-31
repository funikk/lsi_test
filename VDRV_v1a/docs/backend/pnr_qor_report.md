# VDRV_v1a バックエンド物理設計 (PnR) & QoR 設計仕様書

## 1. 物理設計環境および設定概要

本ドキュメントは、`VDRV_v1a_core` に対する LibreLane / OpenROAD 物理設計（Place and Route / PnR）環境の設定、制約条件、および品質目標 (QoR: Quality of Results) を定義します。

### 1.1 基本設計パラメータ
* **対象設計名 (DESIGN_NAME)**: `VDRV_v1a_core`
* **プロセス技術**: SkyWater 130nm CMOS (`sky130_fd_sc_hd`)
* **目標動作周波数**: 100 MHz (クロック周期: 10.0 ns)
* **コア目標利用率 (FP_CORE_UTIL)**: 40 %
* **配置目標密度 (PL_TARGET_DENSITY_PCT)**: 45 %
* **最大ファンアウト制約 (MAX_FANOUT_CONSTRAINT)**: 20
* **設定ファイル**:
  - PnR 構成定義: [config.json](../../pnr/config.json)
  - タイミング制約 (SDC): [constraint.sdc](../../pnr/constraint.sdc)
  - ダイ境界ピン配置定義: [pin_order.cfg](../../pnr/pin_order.cfg)

---

## 2. タイミング制約 (SDC) の要点

OpenROAD / OpenSTA 互換性ガイドラインに従い、以下の制約方針を適用しています：
1. **クロック定義**:
   - `create_clock -name clk -period 10.0000 [get_ports {clk}]`
   - クロック不確かさ: 0.25 ns (`set_clock_uncertainty`)
   - クロック遷移時間: 0.15 ns (`set_clock_transition`)
2. **SRAM インターフェース遅延 (OpenRAM 互換モデル)**:
   - 入力遅延: 4.0 ns (T_co ~3.5ns + 0.5ns マージン)
   - 出力遅延: 2.0 ns (T_su ~1.5ns + 0.5ns マージン)
3. **擬似パス (False Path)**:
   - 非同期リセット (`rst_n`)
   - 低速シリアル通信 (`uart_rx`, `uart_tx`)
   - 準静的負荷ステート観測ピン (`mac_load_mode_en`, `crc_load_mode_en`, `cpu_load_state[*]`)
4. **リセット同期 FF 近傍配置制約**:
   - `set_dont_touch` は OpenSTA で構文エラーとなるため一切使用せず、`set_max_delay 2.0` を用いて階層ピン間にタイトな遅延制約を設定。

---

## 3. ピン配置境界定義 (`pin_order.cfg`)

チップ境界における I/O ピンの物理的配置面を以下のように制御します：
* **North (北側)**: システムクロック (`clk`), リセット (`rst_n`), `trap_out`, 負荷状態観測ピン (`mac_load_mode_en`, `crc_load_mode_en`, `cpu_load_state.*`)
* **South (南側)**: UART シリアルポート (`uart_rx`, `uart_tx`)
* **West (西側)**: 命令メモリ (IMEM) バスポート (`imem_*`)
* **East (東側)**: 共有データメモリ (DMEM) バスポート (`dmem_*`)

---

## 4. 実行コマンド

```bash
# 1. PnR フロー実行 (進捗バー非表示オプション付与)
make pnr

# リモートホストへのオフロード実行 (環境変数 PNR_REMOTE_HOST 設定時)
make PNR_REMOTE=<remote_host> pnr

# 2. QoR およびフェーズ別実行時間レポート生成
make pnr_qor
```

---

## 5. QoR サインオフ目標基準 (Signoff Criteria)

| 評価指標 | 目標値 | 許容限界 | 備考 |
| :--- | :---: | :---: | :--- |
| **Setup WNS (Worst Negative Slack)** | $\ge 0.00$ ns | $-0.10$ ns | 100 MHz 動作サインオフ |
| **Hold WNS** | $\ge 0.00$ ns | $0.00$ ns | ホールド違反ゼロ |
| **Max Slew Violations** | 0 | 0 | スルーレート違反ゼロ |
| **Max Cap Violations** | 0 | 0 | 負荷容量違反ゼロ |
| **DRC (Design Rule Check) Errors** | 0 | 0 | Magic / KLayout DRC ゼロ |
| **LVS (Layout Versus Schematic)** | Netlists Match | Netlists Match | 回路図・レイアウト完全一致 |
