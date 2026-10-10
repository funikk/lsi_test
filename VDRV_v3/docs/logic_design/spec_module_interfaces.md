# VDRV_v3 モジュール間インターフェース仕様書

[spec_top.md](../system_architecture/spec_top.md) を実装するための、ブロック間のポート・レジスタ定義。各ブロックの実装者はこの文書に**厳密に**従うこと。

---

## 1. 共通規約

- クロックは単一の `clk`（立ち上がりエッジ）。リセットは `rst_n`（非同期アサート・active-low）。
- Verilog-2005で書く（`iverilog -g2012` と `verilator -Wall` でエラー・警告が出ないこと）。SystemVerilog固有の構文は使わない。
- `initial` 文、`#` 遅延、`$display` はRTLに書かない（テストベンチのみ）。
- PDKに依存するセルは、必ず `common/rtl/` のラッパー経由で使う（`vdrv_icg`、`vdrv_sram_wrap`、`vdrv_iso_and`）。
- 定数 `G`（PDグループ数＝タイル行数）は **1〜8** の範囲とする。

### 1.1 MMIOスレーブ共通インターフェース

AON内の各ブロックは、次のポートを持つ（PicoRV32のネイティブバスをトップでデコードしたもの）。

```verilog
input  wire        mmio_valid,   // このブロックが選択されている（アドレスデコード済み）
input  wire [7:0]  mmio_addr,    // ブロック内のバイトオフセット（下位2bitは常に0）
input  wire [3:0]  mmio_wstrb,   // 0: 読み出し、非0: 書き込み（ワード単位で扱ってよい）
input  wire [31:0] mmio_wdata,
output reg  [31:0] mmio_rdata,
output reg         mmio_ready
```

- `mmio_valid && !mmio_ready` のとき、次のサイクルで `mmio_ready <= 1`（1サイクルパルス）。
- 読み出しデータは `mmio_ready` と同じサイクルで `mmio_rdata` に出す（レジスタ出力）。
- 書き込みは `mmio_valid && !mmio_ready && mmio_wstrb != 0` のサイクルで反映する。
- 定義されていないオフセットは、読み出しで0を返し、書き込みは無視する。

---

## 2. 共通ラッパー（common/rtl/）

```verilog
module vdrv_icg (input wire clk_i, input wire en_i, input wire te_i, output wire clk_o);
// clk_o = clk_i & latch(en_i | te_i)  （clk_iがLowのときにラッチが透過）

module vdrv_sram_wrap #(parameter AW = 10, parameter DW = 32) (
    input  wire          clk,
    input  wire          ce,      // チップイネーブル
    input  wire          we,      // 1: 書き込み
    input  wire [AW-1:0] addr,
    input  wire [DW-1:0] wdata,
    input  wire [DW/8-1:0] wmask, // バイト書き込みマスク
    output reg  [DW-1:0] rdata    // 1サイクルレイテンシ
);

module vdrv_iso_and #(parameter W = 1) (input wire iso_en, input wire [W-1:0] d, output wire [W-1:0] q);
// q = iso_en ? 0 : d
```

---

## 3. 負荷タイル `load_tile`（blocks/load_tile/）

### 3.1 ポート

```verilog
module load_tile #(
    parameter TILE_TYPE = 0,      // 0: 標準、1: 低活性、2: SRAM
    parameter [7:0] TILE_ID = 8'h00, // {行[3:0], 列[3:0]}
    parameter MAC_ROWS = 4,
    parameter MAC_COLS = 4
)(
    input  wire        clk,
    input  wire        rst_n,        // = グローバルrst_n & pd_rst_n[行]
    // 設定バス（タイル内で1段FF受け）
    input  wire        cfg_valid,
    input  wire [7:0]  cfg_tile_id,
    input  wire [4:0]  cfg_addr,
    input  wire [31:0] cfg_wdata,
    // 共通制御（タイル内で1段FF受け）
    input  wire        pg_sync,      // 1サイクルパルス
    input  wire [1:0]  profile_id,
    // 出力（FF出力）
    output wire [31:0] sig_out,
    output wire        load_active   // 観測用（パターン生成器の出力）
);
```

### 3.2 タイルIDのマッチング

`cfg_tile_id` が次のいずれかのとき、そのタイル宛ての書き込みとする。
- `cfg_tile_id == TILE_ID`
- `cfg_tile_id[7:4] == 4'hF` かつ `cfg_tile_id[3:0] == TILE_ID[3:0]`（列ブロードキャスト）
- `cfg_tile_id[3:0] == 4'hF` かつ `cfg_tile_id[7:4] == TILE_ID[7:4]`（行ブロードキャスト）
- `cfg_tile_id == 8'hFF`（全タイル）

このため、行・列のインデックスは 0〜14 に制限される。

### 3.3 タイル内レジスタ（`cfg_addr`）

| cfg_addr | 名前 | ビット |
|:--|:--|:--|
| `{0, p[1:0], 2'd0}` | `PG_CTRL[p]` | [1:0] `PG_MODE`、[8:4] `ACT_LEVEL`（0〜16）、[12] `GATE_MODE` |
| `{0, p[1:0], 2'd1}` | `PG_TIMING[p]` | [15:0] `PG_PERIOD`、[31:16] `PG_DUTY` |
| `{0, p[1:0], 2'd2}` | `PG_PHASE[p]` | [15:0] `PG_PHASE` |
| `{0, p[1:0], 2'd3}` | 予約 | |
| `5'h10` | `TILE_CTRL` | [0] `SIG_CLEAR`（1を書くとシグネチャを0にする。セルフクリア）、[1] `SEED_LOAD`（1を書くとLFSRにシードを読み込む）、[2] `SEED_MIX_ID`（1ならシードにTILE_IDを混ぜる。保持） |
| `5'h11` | `SEED` | [31:0] シード |

p＝プロファイル番号（0〜3）。実際に使うプロファイルは `profile_id` で選ぶ。リセット後は全プロファイルが `PG_MODE`=0（OFF）。
タイルからは読み出しできない（シグネチャは `sig_out` で常時出力）。

### 3.4 パターン生成器の動作

- 位相カウンタ `pc`（16bit）：`pg_sync` で `pc <= PG_PHASE` にする。それ以外のサイクルは `pc <= (pc + 1 >= PG_PERIOD) ? 0 : pc + 1`。
- `load_on` は次のとおり。
  - `PG_MODE`=0：0
  - `PG_MODE`=1：1
  - `PG_MODE`=2：`pc < PG_DUTY`
  - `PG_MODE`=3：内部の16bit LFSRのMSB（毎サイクル更新）
- `PG_PERIOD`=0 は `PG_PERIOD`=1 と同じに扱う。

---

## 4. Tile Config Bridge `tile_cfg_bridge`（blocks/tile_cfg_bridge/）

```verilog
module tile_cfg_bridge #(parameter NT = 6) (
    input  wire clk, input wire rst_n,
    // MMIO (1.1節)
    ...,
    // 設定バス出力（すべてFF出力）
    output reg         cfg_valid,
    output reg  [7:0]  cfg_tile_id,
    output reg  [4:0]  cfg_addr,
    output reg  [31:0] cfg_wdata,
    output reg         sw_pg_sync,      // 1サイクルパルス
    output reg  [1:0]  sw_profile_id,
    // シグネチャ入力（isolation後）
    input  wire [NT*32-1:0] tile_sig    // タイルkは [k*32 +: 32]
);
```

| オフセット | 名前 | 属性 | 内容 |
|:--|:--|:--|:--|
| `0x00` | `CFG_TARGET` | RW | [7:0] tile_id、[12:8] cfg_addr |
| `0x04` | `CFG_WDATA` | W | 書き込むと、`CFG_TARGET` とこの値で `cfg_valid` を1サイクル出す |
| `0x08` | `CTRL` | RW | [0] 1を書くと `sw_pg_sync` パルス（読み出しは0）、[5:4] `sw_profile_id` |
| `0x0C` | `SIG_SEL` | RW | 読み出すタイルの番号（0〜NT-1） |
| `0x10` | `SIG_DATA` | R | `tile_sig[SIG_SEL]` |
| `0x14` | `SIG_XOR` | R | 全タイルの `tile_sig` のXOR |
| `0x18` | `NUM_TILES` | R | NT |

`SIG_DATA` と `SIG_XOR` は、MUX/XORの結果を毎サイクルFFに取り込んだ値を返してよい（2サイクル程度遅れてもよい）。

---

## 5. Power Manager `pwr_manager`（blocks/pwr_manager/）

```verilog
module pwr_manager #(parameter G = 2) (
    input  wire clk, input wire rst_n,
    // MMIO (1.1節)
    ...,
    // Load Sequencerからのハードウェア要求
    input  wire          hw_direct_active,  // 1のとき hw_pd_req を PD_REQ の代わりに使う
    input  wire [7:0]    hw_pd_req,         // 下位Gビットを使用
    // 物理側へ（すべてFF出力、active-high）
    output reg  [G-1:0]  sw_trickle_en,
    input  wire [G-1:0]  sw_trickle_ack,
    output reg  [G-1:0]  sw_main_en,
    input  wire [G-1:0]  sw_main_ack,
    output reg  [G-1:0]  iso_en,            // リセット後は1
    output reg  [G-1:0]  pd_rst_n,          // リセット後は0
    output wire [G-1:0]  pd_on              // 状態がONのグループ
);
```

### 5.1 レジスタ

| オフセット | 名前 | 属性 | 内容 |
|:--|:--|:--|:--|
| `0x00` | `PD_REQ` | RW | [G-1:0] グループごとのON要求 |
| `0x04` | `PD_STATUS` | R | [7:0] ON、[15:8] 遷移中、[23:16] 実効要求 |
| `0x08` | `T_TRICKLE` | RW | [15:0]（リセット値 16） |
| `0x0C` | `T_MAIN` | RW | [15:0]（リセット値 16） |
| `0x10` | `STAGGER` | RW | [15:0]（リセット値 0） |
| `0x14` | `PD_ORDER` | RW | エントリkは [4k+3:4k]。リセット値 `0x76543210` |
| `0x18` | `UNSAFE_MODE` | RW | [0] |

### 5.2 グループごとのFSM

| 状態 | trickle_en | main_en | pd_rst_n | iso_en | 遷移条件 |
|:--|:--:|:--:|:--:|:--:|:--|
| OFF | 0 | 0 | 0 | 1 | スケジューラから起動されたら TRICKLE（UNSAFEなら MAIN） |
| TRICKLE | 1 | 0 | 0 | 1 | `sw_trickle_ack` かつ 状態に入ってから `T_TRICKLE` サイクル経過 → MAIN |
| MAIN | 1 | 1 | 0 | 1 | `sw_main_ack` かつ `T_MAIN` サイクル経過 → RST_REL。UNSAFEなら1サイクルで RST_REL |
| RST_REL | 1 | 1 | 1 | 1 | 4サイクル後 → ON |
| ON | 1 | 1 | 1 | 0 | 実効要求が0 → ISO |
| ISO | 1 | 1 | 1 | 1 | 2サイクル後 → SW_OFF |
| SW_OFF | 1 | 1 | 0 | 1 | 2サイクル後 → OFF（スイッチをOFF） |

UNSAFEのときは、MAIN状態で trickle_en と main_en の両方を同時に1にする。

### 5.3 投入スケジューラ

- 実効要求が1で、状態がOFFのグループを「待ち」とする。
- `PD_ORDER` のエントリを k=0,1,…,G-1 の順に見て、待ちのグループを1つずつ起動する。1つ起動したら `STAGGER` サイクル待ってから次を起動する。
- `STAGGER`=0、または `UNSAFE_MODE`=1 のときは、待ちのグループを同じサイクルですべて起動する。
- `PD_ORDER` に含まれない（G以上の値の）エントリは飛ばす。

### 5.4 テストベンチ用スイッチモデル（common/tb/vdrv_pwr_switch_model.v）

```verilog
module vdrv_pwr_switch_model #(parameter DELAY = 8) (input wire clk, input wire rst_n, input wire en, output reg ack);
// en が DELAY サイクル連続で1なら ack=1。en=0 になったら DELAY サイクル後に ack=0。
```

---

## 6. Load Sequencer `load_sequencer`（blocks/load_sequencer/、v2から拡張）

```verilog
module load_sequencer (
    input  wire clk, input wire rst_n,
    // UART（v2と同じ。step_state を profile_id として扱う）
    input  wire cmd_set_step, input wire cmd_start_seq, input wire cmd_stop_seq,
    input  wire [3:0] step_id, input wire [1:0] step_state, input wire [15:0] step_duration,
    // MMIO (1.1節)
    ...,
    // 出力（すべてFF出力）
    output wire       hw_direct_active,  // running && !irq_mode
    output reg        running,
    output reg        seq_done,          // ONESHOTで最終ステップ終了後に1（再起動で0）
    output reg        seq_pg_sync,       // 各ステップ開始時に1サイクルパルス
    output reg  [1:0] cur_profile_id,
    output reg  [7:0] cur_pd_req,
    output reg  [1:0] cur_marker,
    output reg  [2:0] cur_em_ctrl,
    output reg  [3:0] cur_step,
    output reg        cpu_irq            // irq_modeでステップ遷移時にパルス
);
```

| オフセット | 名前 | 属性 | 内容 |
|:--|:--|:--|:--|
| `0x00` | `SEQ_CTRL` | RW | [0] `IRQ_MODE`、[1] `SEQ_ENABLE`、[2] `ONESHOT`、[7:4] `TOTAL_STEPS`（最終ステップの番号）、[31:16] `TICK_DIV`（1 tick のサイクル数-1、リセット値 49） |
| `0x04` | `SEQ_STATUS` | R | [0] running、[1] seq_done、[7:4] cur_step |
| `0x40 + 8s` | `STEP_W0[s]` | RW | [15:0] `DURATION`、[17:16] `PROFILE_ID`、[21:20] `MARKER`、[26:24] `EM_CTRL` |
| `0x44 + 8s` | `STEP_W1[s]` | RW | [7:0] `PD_REQ` |

- `SEQ_ENABLE` を0→1にする（またはUARTのSTART）と、ステップ0から開始する。開始したサイクルで `seq_done <= 0`、ステップ0の値を `cur_*` に出し、`seq_pg_sync` を出す。
- 各ステップの長さは `(DURATION + 1)` tick。
- `TOTAL_STEPS` のステップが終わったら、`ONESHOT`=0 ならステップ0に戻り、`ONESHOT`=1 なら `running <= 0`、`seq_done <= 1` にする（`cur_*` は最後の値を保持）。
- `SEQ_ENABLE` を0にする（またはUARTのSTOP）と停止する。
- UARTの `SET_STEP` は `DURATION`←`step_duration`、`PROFILE_ID`←`step_state` を書き込む（他のフィールドは変えない）。

---

## 7. System Ctrl `sys_ctrl`（blocks/sys_ctrl/）

```verilog
module sys_ctrl (
    input  wire clk, input wire rst_n,
    // MMIO (1.1節)
    ...,
    input  wire [3:0] scenario_sel,  // 非同期ピン。内部で2段FF同期化
    output wire       scenario_done,
    output wire       sig_ok,
    output wire [1:0] sw_marker,
    output wire [7:0] sig_out
);
```

| オフセット | 名前 | 属性 | 内容 |
|:--|:--|:--|:--|
| `0x00` | `SCENARIO` | R | [3:0] 同期化した `scenario_sel` |
| `0x04` | `STATUS` | RW | [0] `scenario_done`、[1] `sig_ok` |
| `0x08` | `MARKER` | RW | [1:0] `sw_marker` |
| `0x0C` | `SIG_OUT` | RW | [7:0] `sig_out` |
| `0x10` | `CYCLE` | R | フリーランの32bitサイクルカウンタ |

---

## 8. EM Stress Block `em_stress`（blocks/em_stress/）

```verilog
module em_stress #(parameter W = 32, parameter FANOUT = 64) (
    input  wire clk, input wire rst_n,
    // MMIO (1.1節)
    ...,
    input  wire       hw_direct_active,
    input  wire [2:0] hw_em_ctrl
);
```

| オフセット | 名前 | 属性 | 内容 |
|:--|:--|:--|:--|
| `0x00` | `EM_CTRL` | RW | [0] バスEN、[1] ファンアウト網EN、[2] バスのパターン（0: 交互反転、1: LFSR） |
| `0x04` | `EM_SIG` | R | 受信側シグネチャ（32bit MISR） |

実効制御 = `hw_direct_active ? hw_em_ctrl : EM_CTRL`。

構造（物理配置のため、サブモジュールの階層名を固定する）
- `u_tx`（`em_tx_bank`）：W bitの送信FF。バスEN時、パターン0なら毎サイクル反転（リセット値は `0101…`）、パターン1ならLFSR。
- `u_rx`（`em_rx_bank`）：W bitの受信FF。`u_tx` の出力を毎サイクル取り込む。
- `u_fo`（`em_fanout_net`）：ソースFF 1個（EN時に毎サイクル反転）が `FANOUT` 個のシンクFFを駆動する。シンクFF i は `sink[i] <= src ^ sink[(i+1) % FANOUT]`（等価なFFが合成で併合されないようにするため）。シンク出力はXORで縮約する。
- 受信FF群の値とファンアウト網の縮約値はMISRに取り込み、`EM_SIG` で読めるようにする。
- 送信・受信・ソースのFFには `(* keep *)` 属性を付ける。

---

## 9. トップ（top/rtl/VDRV_v3_core.v）での結線

- `profile_id` = `hw_direct_active ? cur_profile_id : sw_profile_id`
- `pg_sync` = `seq_pg_sync | sw_pg_sync`（FFに通して全タイルへ配る）
- `marker` = `hw_direct_active ? cur_marker : sw_marker`
- タイル行gの `rst_n` = `rst_n & pd_rst_n[g]`
- タイル行gの `sig_out` は、AON側で `vdrv_iso_and`（`iso_en[g]`）を通してから `tile_cfg_bridge` に入れる。
- `POWER_AWARE_SIM` を定義したときは、`pd_on[g]` が0の間、タイル行gの `sig_out` をXにする（isolation前）。
- IRQ：`irq[3]` = `cpu_irq`（Load Sequencer）
