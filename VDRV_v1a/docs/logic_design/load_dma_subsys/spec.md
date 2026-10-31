# Load DMA Subsystem 仕様書 (`blocks/load_dma_subsys`)

## 1. 概要 (Overview)
`load_dma_subsys` は、VDRV_v1a チップにおいて高スイッチング負荷生成とデータ移動（DMA: Direct Memory Access）を一元管理する統合サブシステムである。

本モジュールは、積和演算負荷コア（`mac_load_core`）、巡回冗長検査負荷コア（`crc_load_core`）、および128ビット擬似乱数生成器（`lfsr_prng_ctrl`）を内蔵し、CPUからのMMIO制御（ソフトウェア制御モード）と、負荷シーケンサ（`load_sequencer`）からのサイクル精度ハードウェア直接制御（HW-Directモード）の両方を透過的に調停・実行する。

また、暗号機能への依存を完全に排除し、MACコアおよびCRCコアの独立/同時実行と、それらの演算結果のXOR合成出力をサポートする高機能DMAエンジンを提供する。

---

## 2. モジュールポート定義 (Port Specifications)

```verilog
module load_dma_subsys (
    input  wire        clk,
    input  wire        rst_n,

    // Hardware-direct load control from load_sequencer
    input  wire        hw_load_mode_active,
    input  wire        hw_mac_load_en,
    input  wire        hw_crc_load_en,

    // MMIO Slave Interface (from CPU, 0x8000_0000 - 0x8000_0048)
    input  wire        mmio_valid,
    input  wire [3:0]  mmio_wstrb,
    input  wire [31:0] mmio_addr,
    input  wire [31:0] mmio_wdata,
    output reg  [31:0] mmio_rdata,
    output reg         mmio_ready,

    // DMA Master Interface (to DMEM Arbiter)
    output reg         dma_valid,
    output reg  [3:0]  dma_wstrb,
    output reg  [31:0] dma_addr,
    output reg  [31:0] dma_wdata,
    input  wire [31:0] dma_rdata,
    input  wire        dma_ready
);
```

### ポート一覧

| ポート名 | 方向 | ビット幅 | 説明 |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | システムクロック (100 MHz 想定) |
| `rst_n` | Input | 1 | 非同期アクティブ・ロー・リセット |
| `hw_load_mode_active` | Input | 1 | ハードウェア直接負荷制御有効信号 (負荷シーケンサより入力) |
| `hw_mac_load_en` | Input | 1 | ハードウェア直接MAC負荷コア動作イネーブル |
| `hw_crc_load_en` | Input | 1 | ハードウェア直接CRC負荷コア動作イネーブル |
| `mmio_valid` | Input | 1 | MMIOスレーブ要求有効信号 |
| `mmio_wstrb` | Input | 4 | MMIOバイト書き込みストローブ (4'b0000: リード, 4'b1111: ライト) |
| `mmio_addr` | Input | 32 | MMIOアクセスアドレス (ベース `0x8000_0000`) |
| `mmio_wdata` | Input | 32 | MMIO書き込みデータ |
| `mmio_rdata` | Output | 32 | MMIO読み出しデータ |
| `mmio_ready` | Output | 1 | MMIO応答レディ信号 (1サイクル応答) |
| `dma_valid` | Output | 1 | DMAマスタDMEMメモリアクセス要求信号 |
| `dma_wstrb` | Output | 4 | DMAマスタ書き込みストローブ (4'b0000: リード, 4'b1111: ライト) |
| `dma_addr` | Output | 32 | DMAマスタメモリアドレス |
| `dma_wdata` | Output | 32 | DMAマスタ書き込みデータ |
| `dma_rdata` | Input | 32 | DMEMからの読み出しデータ |
| `dma_ready` | Input | 1 | DMEMアービタからのアクセス応答レディ信号 |

---

## 3. MMIOレジスタマップ (`0x8000_0000` ベース)

| オフセット | レジスタ名 | 属性 | ビット定義と機能説明 |
| :--- | :--- | :---: | :--- |
| `0x00` | `REG_CTRL` | R/W | **サブシステム制御レジスタ**<br>・bit[0]: `DMA_START` (ライト1で1サイクルパルス `dma_start_pulse` を発行、自己クリア)<br>・bit[1]: `SW_MAC_LOAD_EN` (ソフトウェアMAC連続負荷動作イネーブル)<br>・bit[2]: `SEED_LOAD` (ライト1でPRNGへシードロードパルスを発行、自己クリア)<br>・bit[3]: `SW_CRC_LOAD_EN` (ソフトウェアCRC連続負荷動作イネーブル)<br>・bit[5:4]: `DMA_MODE_SEL` (DMA処理モード選択)<br>&emsp;`2'b00`: MAC負荷コアのみ実行<br>&emsp;`2'b01`: CRC負荷コアのみ実行<br>&emsp;`2'b10`, `2'b11`: MACコアおよびCRCコアの同時実行 (出力: `mac_out ^ crc_out`)<br>・bit[31:6]: 予約 (0固定) |
| `0x04` | `REG_STATUS` | RO | **サブシステム状態レジスタ**<br>・bit[0]: `DMA_BUSY` (DMAステートマシンがIDLE以外の場合に1)<br>・bit[1]: `DONE` (DMA処理完了、または有限ブロック負荷完了時に1。次回開始時に0クリア)<br>・bit[2]: `MAC_BUSY` (`!mac_ready` かつ DMA待機中またはMAC負荷動作中の場合に1)<br>・bit[3]: `CRC_BUSY` (`!crc_ready` かつ DMA待機中またはCRC負荷動作中の場合に1)<br>・bit[31:4]: 予約 (0固定) |
| `0x10` | `REG_CFG[0]` | R/W | 128ビット構成設定の下位第1ワード (`cfg_in[31:0]`) |
| `0x14` | `REG_CFG[1]` | R/W | 128ビット構成設定の第2ワード (`cfg_in[63:32]`) |
| `0x18` | `REG_CFG[2]` | R/W | 128ビット構成設定の第3ワード (`cfg_in[95:64]`) |
| `0x1C` | `REG_CFG[3]` | R/W | 128ビット構成設定の最上位第4ワード (`cfg_in[127:96]`) |
| `0x20` | `REG_SEED[0]` | R/W | 128ビットPRNG初期シードの下位第1ワード (リセット値: `0xA5A5A5A5`) |
| `0x24` | `REG_SEED[1]` | R/W | 128ビットPRNG初期シードの第2ワード (リセット値: `0x5A5A5A5A`) |
| `0x28` | `REG_SEED[2]` | R/W | 128ビットPRNG初期シードの第3ワード (リセット値: `0x01234567`) |
| `0x2C` | `REG_SEED[3]` | R/W | 128ビットPRNG初期シードの最上位第4ワード (リセット値: `0x89ABCDEF`) |
| `0x30` | `REG_PRNG_DATA[0]` | RO | 現在の128ビットPRNG出力の下位第1ワード (`prng_data_128[31:0]`) |
| `0x34` | `REG_PRNG_DATA[1]` | RO | 現在の128ビットPRNG出力の第2ワード (`prng_data_128[63:32]`) |
| `0x38` | `REG_PRNG_DATA[2]` | RO | 現在の128ビットPRNG出力の第3ワード (`prng_data_128[95:64]`) |
| `0x3C` | `REG_PRNG_DATA[3]` | RO | 現在の128ビットPRNG出力の最上位第4ワード (`prng_data_128[127:96]`) |
| `0x40` | `REG_SRC_ADDR` | R/W | DMAソースDMEM開始バイトアドレス |
| `0x44` | `REG_DST_ADDR` | R/W | DMAデスティネーションDMEM開始バイトアドレス |
| `0x48` | `REG_LEN` | R/W | 処理ブロック数（1ブロック = 128ビット = 16バイト）<br>・`0`: ソフトウェア負荷モード時、CPUが停止するまで無限連続実行<br>・`>0`: 指定ブロック数完了後に自動停止、`REG_CTRL[1], [3]` を自己クリアし `DONE` をセット |

---

## 4. 負荷生成モード制御アーキテクチャ (Load Mode Control)

### 4.1 イネーブル調停論理
負荷コアの有効化信号は、HW-Directモード信号（`hw_load_mode_active`）により優先選択される。

```verilog
wire mac_load_en = hw_load_mode_active ? hw_mac_load_en : reg_ctrl[1];
wire crc_load_en = hw_load_mode_active ? hw_crc_load_en : reg_ctrl[3];
wire any_load_en = mac_load_en || crc_load_en;
```

### 4.2 ハードウェア直接モード (HW-Direct Mode: `hw_load_mode_active == 1`)
- 負荷シーケンサ（`load_sequencer`）からのサイクル精度制御信号（`hw_mac_load_en`, `hw_crc_load_en`）に従い、各コアを完全に自律・独立して実行する。
- 動的ステップ切り替え（MACのみ実行 → CRCのみ実行 → 両方同時実行 → 停止）をサポートし、コアがレディ状態になり次第、即座にブロック起動パルスを発行する。
- シーケンサ駆動中はソフトウェアの `REG_LEN` 減算や自動クリア論理はバイパスされ、シーケンサの指示通りの時間幅で高密度負荷を連続生成する。

### 4.3 ソフトウェア有限/無限ブロック負荷モード (`hw_load_mode_active == 0`)
- `REG_LEN == 0` の場合: CPUが `REG_CTRL` にて各イネーブルを0に落とすまで、コアはバック・トゥ・バックで無限に連続稼働する。
- `REG_LEN > 0` の場合:
  1. 指定されたブロック数（`load_rem_blocks`）をセットし、`DONE` フラグをクリアする。
  2. 有効化されたコア（MACのみ、CRCのみ、またはMAC+CRC両方）が1ブロック（10サイクル）完了するごとにカウンタをデクリメントする。
  3. 最終ブロック（`load_rem_blocks == 1`）の完了エッジにおいて、`REG_STATUS[1]` (`DONE`) をアサートし、`REG_CTRL[1]` および `REG_CTRL[3]` をハードウェア自動クリアする。

### 4.4 PRNG自動更新プロトコル
- 負荷モード中（`any_load_en == 1`）、各ブロックの起動時（`mac_start || crc_start`）にPRNGクロックイネーブル `prng_en` を1サイクルアサートする。
- 各ブロックは常に新しい128ビット疑似乱数ベクトルを入力データとして取り込み、演算を実行するため、高周波数の電力スイッチングとIR-Drop過渡電流が持続的に発生する。

---

## 5. DMAエンジン動作仕様 (DMA Engine)

DMA転送エンジンは、`!any_load_en`（負荷モード非実行時）において、CPU指示に従いDMEMからの128ビットブロック読み出し、指定負荷コアでのパイプライン変換、およびDMEMへの演算結果書き戻しを自律実行する。

### 5.1 DMAステートマシン

```
[DMA_IDLE]
    │ (dma_start_pulse && reg_len > 0)
    ▼
[DMA_READ_WORD]   <── 4ワード (128bit) をDMEMから読み出し
    │ (word_cnt == 3 && dma_ready)
    ▼
[DMA_CORE_START]  ─── モード選択に基づき mac_start / crc_start をパルス駆動
    │ (1 cycle)
    ▼
[DMA_CORE_WAIT]   ─── 選択されたコアの ready 復帰を待機 (10 cycles)
    │ (mac_ready && crc_ready)
    ▼
[DMA_WRITE_WORD]  <── 演算結果 (out_buf) をDMEMへ4ワード書き込み
    │ (word_cnt == 3 && dma_ready)
    ├─ (rem_blocks > 1) ──> [DMA_READ_WORD] (次の16バイトへポインタ加算)
    ▼ (rem_blocks == 1)
[DMA_DONE_ST]     ─── REG_STATUS[1] (DONE) をセット
    │
    ▼
[DMA_IDLE]
```

### 5.2 DMA演算モード選択 (`DMA_MODE_SEL`)
- **`2'b00` (MAC Mode)**:
  - `mac_start` をアサートし、MACシストリックアレイコアで10サイクル演算。
  - 出力バッファ: `out_buf <= mac_data_out`
- **`2'b01` (CRC Mode)**:
  - `crc_start` をアサートし、CRC並列チャンネルコアで10サイクル演算。
  - 出力バッファ: `out_buf <= crc_data_out`
- **`2'b10` / `2'b11` (Dual MAC+CRC XOR Mode)**:
  - `mac_start` と `crc_start` を同時にアサートし、両コアを完全並列に10サイクル演算。
  - 両コアの完了を確認後、両者の128ビット演算出力をビットワイズXOR合成してDMEMへ書き戻す:
    $$\text{out\_buf} = \text{mac\_data\_out} \oplus \text{crc\_data\_out}$$

---

## 6. 内部サブモジュール構成

1. **`lfsr_prng_ctrl` (`blocks/lfsr_prng/rtl/lfsr_prng_ctrl.v`)**:
   - 32ビットLFSRユニット×4基による128ビット疑似乱数生成回路。
2. **`mac_load_core` (`blocks/mac_load_core/rtl/mac_load_core.v`)**:
   - 5行×4列のMACシストリックアレイ演算コア（レイテンシ10サイクル）。
3. **`crc_load_core` (`blocks/crc_load_core/rtl/crc_load_core.v`)**:
   - 4並列CRC-32アンロール段＋GF(2^8)リードソロモン症候群ミキサコア（レイテンシ10サイクル）。
