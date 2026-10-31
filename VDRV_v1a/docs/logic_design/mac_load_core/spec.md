# MAC Load Core モジュール仕様書 (`blocks/mac_load_core`)

## 1. 概要 (Overview)
`mac_load_core` は、VDRV_v1a システムにおいて高負荷スイッチングおよび急峻な電圧ドロップ（IR-Drop）を擬似生成するための積和演算（MAC: Multiply-Accumulate）シストリックアレイ型ハードウェア負荷コアである。

`load_dma_subsys` や負荷シーケンサと透過的に接続可能な128ビット入出力ハンドシェイクプロトコル（10クロックサイクルレイテンシ）を持つ統一インターフェースを提供する。

---

## 2. モジュールパラメータ (Module Parameters)

| パラメータ名 | デフォルト値 | 説明 |
| :--- | :--- | :--- |
| `ROWS` | 5 | シストリックアレイの行数 |
| `COLS` | 4 | シストリックアレイの列数 |
| `DATA_WIDTH` | 8 | 入力データ幅（各MACユニットの被乗数・乗数幅） |
| `ACC_WIDTH` | 16 | アキュムレータ幅（各MACユニットの部分和・出力幅） |
| `ITER_CYCLES` | 10 | 1ブロック処理あたりの実行クロックサイクル数 |

> **注記**: デフォルトの 5行×4列（計20基のMACユニット）、8ビット乗算/16ビット累積器の構成により、Yosys論理合成において約10,819セル（目標: 9,500〜11,500セル）の規模を達成する。

---

## 3. インターフェース仕様 (Port Definitions)

```verilog
module mac_load_core #(
    parameter ROWS        = 5,
    parameter COLS        = 4,
    parameter DATA_WIDTH  = 8,
    parameter ACC_WIDTH   = 16,
    parameter ITER_CYCLES = 10
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] data_in,
    input  wire [127:0] cfg_in,
    output reg  [127:0] data_out,
    output reg          ready
);
```

### ポート一覧

| ポート名 | 方向 | ビット幅 | 説明 |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | システムクロック (100MHz 動作想定) |
| `rst_n` | Input | 1 | 非同期アクティブ・ロー・リセット |
| `start` | Input | 1 | 演算開始トリガパルス (1クロック有効) |
| `data_in` | Input | 128 | 128ビット入力データベクトル |
| `cfg_in` | Input | 128 | 128ビット入力設定/初期重みベクトル |
| `data_out` | Output | 128 | 演算完了後の128ビット出力シグネチャ |
| `ready` | Output | 1 | レディ信号 (アイドル時/完了時: 1, 演算中: 0) |

---

## 4. ハンドシェイク動作とタイミング (Handshake Protocol)

`load_dma_subsys` のタイミング仕様に厳密に準拠する。

1. **リセット動作 (`!rst_n`)**:
   - `state_machine <= STATE_IDLE`
   - `ready <= 1'b1`
   - `data_out <= 128'b0`
   - シストリックアレイ内部レジスタは 0 にクリアされる。

2. **演算開始 (`ready == 1'b1` かつ `start == 1'b1`)**:
   - `start` パルスを受信したクロックエッジで `data_in` および `cfg_in` を内部レジスタ（`state_reg`, `cfg_reg`）にラッチする。
   - `ready` を `1'b0` にデアサートし、`STATE_RUN` に遷移する。
   - 内部サイクルカウンタ `iter_cnt` を 0 にリセットする。

3. **演算実行中 (`STATE_RUN`)**:
   - シストリックアレイへのイネーブル信号 `en = 1'b1` をアサートする。
   - 毎サイクル、内部レジスタのビット回転、定数加算、およびシストリックアレイからのフィードバック結果（`feedback_mix`）とのビットレベル合成を行い、全MACユニットの入力へ供給する。
   - これにより、全ユニットが毎サイクル高スイッチング率でトグルし、定数畳み込み（Constant Folding）によるロジック縮退を完全に防ぐ。

4. **演算完了とバック・トゥ・バック動作 (`iter_cnt == ITER_CYCLES - 1`)**:
   - 10サイクル目（`iter_cnt == 9`）のクロックエッジで、最終演算結果を `data_out` にラッチする。
   - `ready` を `1'b1` に復帰させ、`STATE_IDLE` に遷移する。
   - `ready` が `1'b1` に戻ったサイクルで直ちに次の `start` パルスを入力することで、デッドサイクルのない連続バック・トゥ・バック実行（Back-to-Back Execution）が可能である。

---

## 5. 内部アーキテクチャ (Internal Architecture)

1. **シストリックアレイ (`mac_array.v` / `mac_unit.v`)**:
   - 5行×4列の2次元メッシュ構造。
   - 被乗数 `a` は水平方向（左から右）、乗数 `b` および累積値 `c` は垂直方向（上から下）へパイプライン伝搬する。
   - 各ユニットは `mac_out <= c_in + (a_in * b_in)` を実行する。
2. **非線形ビット置換・回転ミキサ**:
   - 128ビットの `state_reg` と `cfg_reg` を異なるビット幅で巡回シフトし、ラウンド定数 `{4{24'h5A5A5A, iter_cnt[7:0]}}` を注入することで、全0入力時でも常に高いトグル率と擬似ランダム拡散性を維持する。
3. **フィードバック折返しロジック (`fold_slices`)**:
   - シストリックアレイから出力されるすべての行・列出力（計 144ビット）を 128ビット境界で排他的論理和合成（XOR fold）し、内部状態へ還元する。
