# VDRV_v2 トップレベルシステム仕様書

## 1. システムブロック図

本システム (VDRV_v2) の全体構成を以下のブロック図に示す。

```mermaid
graph TD
    %% I/O Pins
    clk((clk))
    rst_n((rst_n))
    uart_rx((uart_rx))
    uart_tx((uart_tx))

    %% Core Components
    CPU[PicoRV32 CPU]
    AES_DMA[AES-DMA Subsystem]
    PWR_MGR[AES Power Manager (AON)]
    PD_AES[PD_AES: AES/PRNG]
    DMEM_ARB[DMEM Arbiter]
    UART_CTRL[UART Controller]
    LOAD_SEQ[Load Sequencer]
    IMEM[IMEM 8KB]
    DMEM[DMEM 512B]

    %% Connections
    clk --> CPU
    clk --> AES_DMA
    clk --> PWR_MGR
    clk --> UART_CTRL
    clk --> LOAD_SEQ

    rst_n --> CPU
    rst_n --> AES_DMA
    rst_n --> PWR_MGR
    rst_n --> UART_CTRL
    rst_n --> LOAD_SEQ

    uart_rx --> UART_CTRL
    UART_CTRL --> uart_tx

    CPU <--> IMEM
    CPU <--> DMEM_ARB
    AES_DMA <--> DMEM_ARB
    DMEM_ARB <--> DMEM

    UART_CTRL <--> LOAD_SEQ
    CPU <--> LOAD_SEQ
    CPU <--> UART_CTRL
    CPU <--> AES_DMA
    CPU <--> PWR_MGR
    PWR_MGR --> PD_AES
    AES_DMA <--> PD_AES
```

## 2. トップレベルI/Oピン仕様

VDRV_v2モジュールのトップレベル入出力ピン一覧を以下に示す。

| ピン名 | 入出力 | 幅(bit) | 説明 |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | システムクロック (想定周波数: 100MHz) |
| `rst_n` | Input | 1 | システムリセット (負論理、アクティブロー) |
| `uart_rx` | Input | 1 | UART受信データ入力 |
| `uart_tx` | Output | 1 | UART送信データ出力 |
| `in_valid` | Input | 1 | 旧テンプレート互換入力（VDRV_v2では未使用） |
| `in_data` | Input | 128 | 旧テンプレート互換入力（VDRV_v2では未使用） |
| `out_valid` | Output | 1 | 旧テンプレート互換出力（常に0） |
| `out_data` | Output | 128 | 旧テンプレート互換出力（常に0） |
| `aes_load_mode_en` | Output | 1 | AES負荷要求観測出力 |
| `cpu_load_state` | Output | 2 | CPU負荷状態観測出力 |

## 3. メモリマップ

システムの全体メモリマップを以下に示す。

| ベースアドレス | 終了アドレス | サイズ | モジュール/領域名 | 説明 |
| :--- | :--- | :--- | :--- | :--- |
| `0x0000_0000` | `0x0000_01FF` | 512B | DMEM | 共有データSRAM (PicoRV32/AES-DMA共有) |
| `0x8000_0000` | `0x8000_0048` | 76B | AES/PRNG DMA MMIO | AESおよびPRNG DMA用メモリマップドI/O |
| `0x8000_0100` | `0x8000_0140` | 68B decode | Load Sequencer | `0x8000_0100` の `SEQ_CTRL`。ステップ設定はUART入力 |
| `0x8000_0200` | `0x8000_0204` | 8B | AES Power Manager | AES/PRNG電源状態の要求・監視MMIO |

※IMEM(8KB)は命令フェッチ専用のメモリ空間にマッピングされる前提とする。
