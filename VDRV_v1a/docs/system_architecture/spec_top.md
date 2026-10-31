# VDRV_v1a トップレベルシステム仕様書 (System Architecture Specification)

## 1. 概要 (Overview)

本システム (`VDRV_v1a`) は、RISC-V CPU (`picorv32`) と 2 つの独立した高負荷ストレス生成器（シストリック MAC アレイ `mac_load_core`、リード・ソロモン多項式ミキサ付き並列 CRC コア `crc_load_core`）、疑似乱数生成器 (`lfsr_prng`)、およびハイブリッド負荷シーケンサ (`load_sequencer`) を統合した IR-Drop / $di/dt$ 電源ノイズ耐性評価用の ASIC/SoC テストベッドです。

本構成では、従来の暗号アクセラレータに代わり、演算集約型の MAC アレイとビットトグル密度の高い CRC ジェネレータをハイブリッドに刺激源として利用し、多様な電流変動プロファイルを生成します。

---

## 2. システムブロック図

```mermaid
graph TD
    %% I/O Pins
    clk((clk))
    rst_n((rst_n))
    uart_rx((uart_rx))
    uart_tx((uart_tx))
    trap_out((trap_out))
    mac_en_pin((mac_load_mode_en))
    crc_en_pin((crc_load_mode_en))
    cpu_state_pin((cpu_load_state[2:0]))

    %% Submodules
    CPU[PicoRV32 RISC-V CPU]
    UART[UART Controller / Packet Parser]
    SEQ[Hybrid Load Sequencer]
    DMA_SUBSYS[Load DMA Subsystem]
    PRNG[LFSR PRNG 128-bit]
    MAC[MAC Load Core]
    CRC[CRC Load Core]
    DMEM_ARB[DMEM Bus Arbiter]
    IMEM[Instruction Memory 8KB]
    DMEM[Shared Data SRAM 512B]

    %% Clocks & Resets
    clk --> CPU & UART & SEQ & DMA_SUBSYS
    rst_n --> CPU & UART & SEQ & DMA_SUBSYS

    %% UART to Sequencer
    uart_rx --> UART
    UART --> uart_tx
    UART -->|cmd_set_step / cmd_start / step_state| SEQ

    %% Sequencer Outputs
    SEQ -->|mac_load_mode_en| DMA_SUBSYS & mac_en_pin
    SEQ -->|crc_load_mode_en| DMA_SUBSYS & crc_en_pin
    SEQ -->|cpu_load_state[2:0]| cpu_state_pin
    SEQ -->|hw_direct_active| DMA_SUBSYS
    SEQ -->|cpu_irq (irq3)| CPU

    %% Subsystem internals
    DMA_SUBSYS --- PRNG
    DMA_SUBSYS --- MAC
    DMA_SUBSYS --- CRC

    %% Buses
    CPU -->|IMEM Interface| IMEM
    CPU -->|MMIO 0x8000_01xx| SEQ
    CPU -->|MMIO 0x8000_00xx| DMA_SUBSYS
    CPU -->|Data Interface| DMEM_ARB
    DMA_SUBSYS -->|DMA Master Interface| DMEM_ARB
    DMEM_ARB --> DMEM
    CPU --> trap_out
```

---

## 3. トップレベル I/O ピン仕様

| ピン名 | 入出力 | 幅 (bit) | 説明 |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | システムクロック (100 MHz, 周期 10.0 ns) |
| `rst_n` | Input | 1 | 非同期リセット (Active Low) |
| `in_valid` | Input | 1 | テストベッド互換ピン (Tie-off 可) |
| `in_data` | Input | 128 | テストベッド互換データ入力 (Tie-off 可) |
| `out_valid` | Output | 1 | テストベッド互換ピン (0 出力) |
| `out_data` | Output | 128 | テストベッド互換データ出力 (0 出力) |
| `uart_rx` | Input | 1 | UART シリアル受信ポート (115200 bps) |
| `uart_tx` | Output | 1 | UART シリアル送信ポート (115200 bps) |
| `trap_out` | Output | 1 | PicoRV32 CPU トラップ通知出力 |
| `mac_load_mode_en` | Output | 1 | MAC 高負荷連続刺激アクティブ状態出力 |
| `crc_load_mode_en` | Output | 1 | CRC 高負荷連続刺激アクティブ状態出力 |
| `cpu_load_state` | Output | 3 | 現在のシステム負荷状態 `{cpu_en, crc_en, mac_en}` |

---

## 4. メモリマップ (Memory Map)

CPU は 32 ビットリニアアドレス空間を使用し、データバス調停器およびアドレスデコーダを介して各ブロックへアクセスします。

| アドレス範囲 | サイズ | 領域名 | 説明 |
| :--- | :---: | :--- | :--- |
| `0x0000_0000` - `0x0000_01FF` | 512 B | **DMEM (SRAM)** | 共有データメモリ (128 words)。DMA 転送元/先およびスタック領域 |
| `0x0000_0000` - `0x0000_1FFF` | 8 KB | **IMEM (ROM)** | 命令メモリ (2048 words)。`firmware.hex` が格納される |
| `0x8000_0000` - `0x8000_0048` | 76 B | **Load DMA Subsys** | MAC/CRC DMA 制御、乱数シード設定、設定パラメータ MMIO |
| `0x8000_0100` - `0x8000_014C` | 80 B | **Load Sequencer** | シーケンサ設定、ステートテーブル、UART ステータス MMIO |

---

## 5. 負荷状態定義 (Load States)

`cpu_load_state[2:0]` は各サブブロックの負荷有効ビットで構成されます：
* `bit [0]` (`0x1`): `LOAD_STATE_MAC_BIT` - MAC 負荷コア有効
* `bit [1]` (`0x2`): `LOAD_STATE_CRC_BIT` - CRC 負荷コア有効
* `bit [2]` (`0x4`): `LOAD_STATE_CPU_BIT` - CPU 高電力 ALU/メモリ連打ループ有効

主な動作ステート：
* `3'b000` (`IDLE`): システム低消費電力アイドル
* `3'b001` (`MAC_ONLY`): MAC アレイ単体連続稼働
* `3'b010` (`CRC_ONLY`): CRC 並列 4 チャネル単体連続稼働
* `3'b011` (`MAC+CRC`): ハードウェアストレスコア同時連続稼働
* `3'b111` (`ALL_FULL`): CPU + MAC + CRC 全面フル稼動（最大 IR-Drop モード）
