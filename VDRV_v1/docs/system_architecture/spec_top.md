# VDRV_v1 トップレベルシステム仕様書

## 1. システムブロック図

本システム (VDRV_v1) の全体構成を以下のブロック図に示す。

```mermaid
graph TD
    %% I/O Pins
    clk((clk))
    rst_n((rst_n))
    uart_rx((uart_rx))
    uart_tx((uart_tx))
    trap_out((trap_out))

    %% Core Components
    CPU[PicoRV32 CPU]
    AES_DMA[AES-DMA Subsystem]
    DMEM_ARB[DMEM Arbiter]
    UART_CTRL[UART Controller]
    LOAD_SEQ[Load Sequencer]
    IMEM[IMEM 8KB]
    DMEM[DMEM 512B]

    %% Connections
    clk --> CPU
    clk --> AES_DMA
    clk --> UART_CTRL
    clk --> LOAD_SEQ
    
    rst_n --> CPU
    rst_n --> AES_DMA
    rst_n --> UART_CTRL
    rst_n --> LOAD_SEQ

    uart_rx --> UART_CTRL
    UART_CTRL --> uart_tx
    CPU --> trap_out

    CPU <--> IMEM
    CPU <--> DMEM_ARB
    AES_DMA <--> DMEM_ARB
    DMEM_ARB <--> DMEM

    UART_CTRL <--> LOAD_SEQ
    CPU <--> LOAD_SEQ
    CPU <--> UART_CTRL
    CPU <--> AES_DMA
```

## 2. トップレベルI/Oピン仕様

VDRV_v1モジュールのトップレベル入出力ピン一覧を以下に示す。

| ピン名 | 入出力 | 幅(bit) | 説明 |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | システムクロック (想定周波数: 100MHz) |
| `rst_n` | Input | 1 | システムリセット (負論理、アクティブロー) |
| `uart_rx` | Input | 1 | UART受信データ入力 |
| `uart_tx` | Output | 1 | UART送信データ出力 |
| `trap_out` | Output | 1 | PicoRV32 CPUトラップ状態出力 |

## 3. メモリマップ

システムの全体メモリマップを以下に示す。

| ベースアドレス | 終了アドレス | サイズ | モジュール/領域名 | 説明 |
| :--- | :--- | :--- | :--- | :--- |
| `0x0000_0000` | `0x0000_07FF` | 2KB | DMEM | 共有データSRAM (PicoRV32/AES-DMA共有) |
| `0x8000_0000` | `0x8000_0048` | 76B | AES/PRNG DMA MMIO | AESおよびPRNG DMA用メモリマップドI/O |
| `0x8000_0100` | `0x8000_0140` | 68B | UART & Load Sequencer | UART制御および負荷シーケンサ制御用MMIO |

※IMEM(8KB)は命令フェッチ専用のメモリ空間にマッピングされる前提とする。
