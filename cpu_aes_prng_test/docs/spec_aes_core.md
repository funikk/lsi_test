# AES-128 暗号化コア仕様書 (`aes_core` / `aes_sbox`)

## 1. 概要

`aes_core` は、128-bit 鍵を用いた NIST FIPS-197 規格準拠の AES 暗号化イテレーティブコアです。
面積（ゲート数）とトグル率（IR-Drop ストレス供給性能）の最適バランスを図るため、20 個の S-Box ユニット（`aes_sbox`）を並列配置し、12 クロックサイクルで 1 回の 128-bit 暗号化を完了します。

---

## 2. アーキテクチャおよび処理パイプライン

AES-128 の 10 ラウンド処理を以下の 12 サイクルパイプラインでイテレーティブ実行します：

| サイクル | 処理段階 | 実行内容 |
| :--- | :--- | :--- |
| `Cycle 0` | `IDLE / START` | 入力平文 `state_i` と初期鍵 `key_i` の `AddRoundKey` を実行 |
| `Cycle 1 - 9` | `Round 1 - 9` | 16個の S-Box による `SubBytes` + `ShiftRows` + `MixColumns` + 4個の S-Box によるラウンド鍵生成（`KeyExpansion`） |
| `Cycle 10` | `Round 10 (Final)`| `SubBytes` + `ShiftRows` + `AddRoundKey` (最終ラウンドは `MixColumns` をスキップ) |
| `Cycle 11` | `READY` | 暗号文 `state_o` を確定させ、`ready_o = 1` を出力 |

---

## 3. 入出力信号仕様

| 信号名 | 方向 | ビット幅 | 説明 |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | システムクロック |
| `rst_n` | Input | 1 | アクティブ・ロー リセット |
| `start_i` | Input | 1 | 暗号化開始パルス |
| `key_i` | Input | 128 | 128-bit AES 暗号鍵 |
| `state_i` | Input | 128 | 128-bit 平文データ |
| `state_o` | Output | 128 | 128-bit 暗号文データ |
| `busy_o` | Output | 1 | 暗号化処理中フラグ (1: 処理中) |
| `ready_o` | Output | 1 | 暗号化完了パルス (1: 完了) |

---

## 4. S-Box モジュール仕様 (`aes_sbox`)

- **テーブル方式**: 純粋な組み合わせ論理（8-bit in, 8-bit out の Lookup Logic）として Yosys で合成。
- **並列数**: `aes_core` 内部に 20 個配置。
  - 16 個: ラウンドステート `SubBytes` 処理用（16バイト全並列）
  - 4 個: 鍵拡張 `KeyExpansion` 処理用（SubWord 演算）
- **合成後サイズ**: 1つの S-Box あたり約 765 ゲート。20 個で約 15,300 ゲート。
- **IR-Drop 観点での特質**: 毎クロックサイクルで全 20 個の S-Box に新たなデータが供給されるため、高密度の組合せ論理回路内で巨大な充放電電流（トグル）が発生します。
