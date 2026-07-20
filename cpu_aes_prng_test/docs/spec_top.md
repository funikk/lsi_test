# トップレベルシステム仕様書 (`cpu_aes_prng_top`)

## 1. 概要

`cpu_aes_prng_top` は、IR-Drop（動的電源電圧降下）解析および評価を目的として設計された SOC モジュールです。
32-bit RISC-V CPU（PicoRV32）、命令メモリ（`IMEM`）、共有データ SRAM（`DMEM`）、および AES-128 / LFSR PRNG 複合 DMA サブシステムを統合し、全動作を CPU から柔軟にプログラム制御可能です。

---

## 2. システムブロック図と階層構造

LSI 論理合成および PnR（配置配線）処理を考慮し、RAM メモリ（`IMEM`, `DMEM`）を外部接続用のメモリバスピンとして分離した**中間階層コアモジュール（`cpu_aes_prng_core`）** を導入しています。

```mermaid
graph TD
    CLK[clk / rst_n] --> TOP

    subgraph cpu_aes_prng_top (トップレベル・ラッパー)
        subgraph cpu_aes_prng_core (中間階層コア・論理合成対象)
            CPU[PicoRV32 RISC-V CPU]
            AES_DMA[AES-128 / PRNG DMA サブシステム]
            ARBITER[DMEM バスアビータ]

            CPU -- "mem_instr=0 (Data Bus)" --> ARBITER
            ARBITER -- "0x8000_0000 (MMIO)" --> AES_DMA
        end

        IMEM[IMEM 8KB Instruction RAM]
        DMEM[DMEM 512B Shared Data SRAM]

        CPU -- "imem_* (IMEM Bus)" --> IMEM
        ARBITER -- "dmem_* (DMEM Bus)" --> DMEM
        AES_DMA -- "DMA Master (Priority High)" --> DMEM
    end

    CPU --> TRAP[trap_out]
```

### 階層モジュールの役割
1. **`cpu_aes_prng_core.v` (中間階層コアモジュール)**:
   - CPU、AES-DMA サブシステム、および DMEM バスアビータを包含。
   - `imem_*` (命令バス) および `dmem_*` (データ SRAM バス) を外部ピンとして露出。
   - 大規模 RAM を含まず純粋な論理ゲートのみで構成されるため、**ASIC 論理合成 (Yosys) や PnR フローのトップモジュール**として最適。
2. **`cpu_aes_prng_top.v` (トップレベル・ラッパーモジュール)**:
   - `cpu_aes_prng_core` に対してオンチップ RAM モジュール（`imem.v`, `dmem.v`）を結線。
   - シミュレーション（RTL_SIM / GLS_SIM）の統合検証トップとして動作。

---

## 3. トップレベル入出力ピン仕様

| ピン名 | 方向 | ビット幅 | 説明 |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | システムクロック（想定: 100MHz） |
| `rst_n` | Input | 1 | アクティブ・ロー 非同期リセット |
| `trap_out` | Output | 1 | CPU トラップ出力（1: 未定義命令・メモリ例外時） |

---

## 4. メモリマップ

CPUのデータバス（`mem_instr == 0`）は、アドレスの MSB (`mem_addr[31]`) に応じて以下の領域にデコードされます：

| アドレス範囲 | ターゲット | サイズ / 説明 |
| :--- | :--- | :--- |
| `0x0000_0000 - 0x0000_07FF` | **DMEM** | 共有データ SRAM（512バイト = 128ワード）。CPU および DMA からアクセス可能。 |
| `0x8000_0000 - 0x8000_0048` | **MMIO (AES/PRNG Subsys)** | コントロール/ステータスレジスタ、AES鍵、PRNGシード、PRNGリードバック、DMA設定。 |

*注: 命令メモリ（`IMEM`）は `mem_instr == 1` の場合に呼び出され、`0x0000_0000` アドレスから独立して給餌されます（ハーバード構成）。*

---

## 5. バスアビータとアクセス優先度

`DMEM` へのアクセスは CPU と DMA コントローラの 2 つのマスターによって共有されます。

1. **DMA Priority (優先度: 高)**: DMA 転送処理中（SRAM読み出し/書き戻し）は DMA コントローラが `DMEM` バスを優先占有します。
2. **CPU Access (優先度: 低)**: DMA が非アクティブな間、CPU からの `DMEM` リード/ライト要求が処理されます。

---

## 6. 動作モード

1. **通常 CPU 動作モード**:
   CPUが `IMEM` からファームウェアを実行し、`DMEM` や MMIO レジスタの読み書きを行います。
2. **SRAM DMA 暗号化モード**:
   CPUが DMA パラメータ（転送元/転送先アドレス、長さ）を設定して DMA を起動。DMA が `DMEM` 上のデータを自動読み出し → AES 暗号化 → `DMEM` への暗号文書き戻しを自律実行します。
3. **高負荷 IR-Drop ストレスモード (`LOAD_MODE_EN`)**:
   MMIO `CTRL.LOAD_MODE_EN` を有効にすると、128-bit LFSR PRNG が連続して乱数列を発生させ、AES コアに全速（12サイクル周期）で給餌し続けます。これにより、20個の S-Box を含む AES データパスが全スロットルで連続トグル動作し、最大消費電力・高 IR-Drop ノイズ状態を供給します。
