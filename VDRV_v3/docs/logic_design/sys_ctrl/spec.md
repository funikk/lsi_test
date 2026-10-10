# System Control (`sys_ctrl`) ブロック仕様書

## 1. 概要
`sys_ctrl` は、外部ピンからのシナリオ番号の非同期取り込み・同期化、テストステータス（`scenario_done`, `sig_ok`）や観測用マーカー・シグネチャ出力の制御、およびシステムフリーランカウンタ（`CYCLE`）を提供するAON内制御ブロックである。

## 2. インターフェース仕様
- **クロック / リセット**: `clk`（単一システムクロック）、`rst_n`（非同期アクティブロー）
- **MMIO スレーブ**: 32bitネイティブバス（`mmio_valid`, `mmio_addr[7:0]`, `mmio_wstrb[3:0]`, `mmio_wdata[31:0]`, `mmio_rdata[31:0]`, `mmio_ready`）
- **外部入力ピン**:
  - `scenario_sel[3:0]`: 非同期シナリオ選択入力（内部で2段FFを用いて同期化）
- **観測・出力ピン**:
  - `scenario_done`: シナリオ実行完了フラグ
  - `sig_ok`: シグネチャ照合正常フラグ
  - `sw_marker[1:0]`: ソフトウェアマーカー出力
  - `sig_out[7:0]`: 集計シグネチャ出力（デバッグ用）

## 3. レジスタマップ (Base: 0x8000_0000)
| オフセット | レジスタ名 | 属性 | ビット定義 | 説明 |
|:---|:---|:---:|:---|:---|
| `0x00` | `SCENARIO` | R | [3:0] scenario_sel | 2段FFで同期化されたシナリオ選択ピンの値 |
| `0x04` | `STATUS` | RW | [0] scenario_done<br>[1] sig_ok | ステータスフラグ。出力ピン `scenario_done` および `sig_ok` を駆動 |
| `0x08` | `MARKER` | RW | [1:0] sw_marker | マーカー出力ピン `sw_marker` を駆動 |
| `0x0C` | `SIG_OUT` | RW | [7:0] sig_out | デバッグ出力ピン `sig_out` を駆動 |
| `0x10` | `CYCLE` | R | [31:0] cycle_cnt | リセット解除後、毎クロックインクリメントされるフリーランサイクルカウンタ |
