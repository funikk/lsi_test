# 128-bit LFSR PRNG モジュール仕様書 (`blocks/lfsr_prng`)

## 1. 概要 (Overview)
`lfsr_prng_ctrl` は、VDRV_v1a システムにおいて高密度負荷生成コア（`mac_load_core`、`crc_load_core`）に対して、毎サイクル高エントロピーな動的入力データを供給するための 128ビット線形帰還シフトレジスタ型疑似乱数生成器（LFSR PRNG）である。

独立した 32ビットLFSRユニット（`lfsr_32_ctrl`）を4基並列に配置し、各ユニットが1クロックサイクル内で32ステップのシフト演算をアンロール実行することで、128ビット幅の並列乱数ベクトルを即座に生成する。

---

## 2. 数学モデルと帰還多項式 (Mathematical Model)

各 32ビットLFSRは、周期長 $2^{32}-1$ の最大長系列（M系列）を生成する以下の原始多項式（Primitive Polynomial）に基づく。

$$P(x) = x^{32} + x^{22} + x^2 + x^1 + 1$$

各サイクルにおいて、関数 `next_lfsr32` により32回のフィードバック計算を組み合わせ論理として一括評価する。これにより、1クロックのイネーブル入力（`en == 1`）ごとに全32ビットが完全に更新され、相関の極めて低い擬似乱数列が得られる。

---

## 3. インターフェース仕様 (Port Definitions)

```verilog
module lfsr_prng_ctrl (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         en,
    input  wire         load_seed,
    input  wire [127:0] seed_in,
    output wire [127:0] out
);
```

### ポート一覧

| ポート名 | 方向 | ビット幅 | 説明 |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | システムクロック (100 MHz) |
| `rst_n` | Input | 1 | 同期アクティブ・ロー・リセット |
| `en` | Input | 1 | PRNG更新イネーブル（1サイクル有効で128ビット全て更新） |
| `load_seed` | Input | 1 | 初期シードロードパルス |
| `seed_in` | Input | 128 | 128ビット初期シード入力ベクトル |
| `out` | Output | 128 | 現在の128ビット擬似乱数出力ベクトル |

---

## 4. 内部構成と動作シーケンス

### 4.1 階層構成
- `lfsr_prng_ctrl`:
  - `u_lfsr0` (`lfsr_32_ctrl`): 出力 `out[31:0]`
  - `u_lfsr1` (`lfsr_32_ctrl`): 出力 `out[63:32]`
  - `u_lfsr2` (`lfsr_32_ctrl`): 出力 `out[95:64]`
  - `u_lfsr3` (`lfsr_32_ctrl`): 出力 `out[127:96]`

### 4.2 動作プロトコル
1. **リセット時 (`!rst_n`)**:
   - `out <= 128'b0`
2. **シードロード時 (`load_seed == 1`)**:
   - `out <= seed_in`
   - 全0以外の任意の128ビット初期シードを設定可能。
3. **シフト更新時 (`en == 1` かつ `load_seed == 0`)**:
   - 4基のLFSRユニットが同時に32ステップ進み、新しい128ビット乱数を出力する。
4. **保持時 (`en == 0` かつ `load_seed == 0`)**:
   - 現在の乱数ベクトルを出力端に安定保持する（MMIOからの安定読み出しが可能）。
