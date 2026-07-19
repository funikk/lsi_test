# 128-bit LFSR PRNG モジュール仕様書 (`lfsr_prng_ctrl`)

## 1. 概要

`lfsr_prng_ctrl` は、高周期・高トグル率の 128-bit 疑似乱数列を生成する乱数発生器モジュールです。
4つの 32-bit LFSR コア（`lfsr_32_ctrl`）を並列結合して構成されており、CPU からの動的シード書込みおよび発生した乱数列のリードバックに対応しています。

---

## 2. モジュールブロック構造

```mermaid
graph LR
    subgraph lfsr_prng_ctrl (128-bit)
        SEED[128-bit seed_i] --> L32_0[lfsr_32_ctrl #0]
        SEED --> L32_1[lfsr_32_ctrl #1]
        SEED --> L32_2[lfsr_32_ctrl #2]
        SEED --> L32_3[lfsr_32_ctrl #3]

        LOAD[load_seed_i] --> L32_0
        LOAD --> L32_1
        LOAD --> L32_2
        LOAD --> L32_3

        NEXT[next_i] --> L32_0
        NEXT --> L32_1
        NEXT --> L32_2
        NEXT --> L32_3

        L32_0 --> PRNG_OUT[128-bit prng_data_o]
        L32_1 --> PRNG_OUT
        L32_2 --> PRNG_OUT
        L32_3 --> PRNG_OUT
    end
```

---

## 3. 多項式タップおよび動作原理

各 32-bit LFSR ユニットは、以下の標準 Maximal-Length タップ多項式（周期 \(2^{32} - 1\)）を採用しています：

$$P(x) = x^{32} + x^{22} + x^{2} + x + 1$$

- **Feedback Logic**:
  `feedback = lfsr_reg[31] ^ lfsr_reg[21] ^ lfsr_reg[1] ^ lfsr_reg[0];`
- **Shift Action**:
  `next_reg = {lfsr_reg[30:0], feedback};`

---

## 4. 入出力信号仕様

| 信号名 | 方向 | ビット幅 | 説明 |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | システムクロック |
| `rst_n` | Input | 1 | アクティブ・ロー リセット |
| `load_seed_i` | Input | 1 | シードロードパルス（1のとき `seed_i` をレジスタへ直接ロード） |
| `next_i` | Input | 1 | 乱数更新イネーブル (1で1ステップシフト) |
| `seed_i` | Input | 128 | CPU から設定される 128-bit シード値 |
| `prng_data_o` | Output | 128 | 現在の 128-bit 乱数出力 (CPU リードバックおよび AES 入力用) |

---

## 5. シードゼロ防護メカニズム

LFSR は全ビット `0`（オールゼロ）の状態で停止してしまう性質があります。
本モジュールでは、`load_seed_i` 時またはリセット時に全 128 ビットが 0 であった場合、内部的に初期値 `0xACE1_2345` を自動補填する防護回路を搭載しています。
