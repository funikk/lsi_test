# PicoRV32 RISC-V CPU コア仕様書 (`blocks/picorv32_cpu`)

## 1. 概要 (Overview)
`picorv32_cpu` は、VDRV_v1a システムにおけるメインプロセッサとして動作する、オープンソースの高効率 32ビット RISC-V CPU コア（PicoRV32）である。
RV32I 基本命令セットに準拠し、システム初期化、UART通信パケットの処理、負荷シーケンサ（`load_sequencer`）の設定、および負荷DMAサブシステム（`load_dma_subsys`）の制御を担当する。

さらに、負荷シーケンサのCPU-IRQモードと連携し、スリープ（待機）状態から割り込みハンドラへの復帰時に生じる急峻な消費電流変動（$di/dt$ CPU Wake-up Transient）を意図的に励起し、チップ過渡応答特性の評価に寄与する。

---

## 2. モジュールパラメータ (Module Parameters)

| パラメータ名 | デフォルト値 | 説明 |
| :--- | :--- | :--- |
| `ENABLE_COUNTERS` | 1 | 性能カウンタ（RDCYCLE, RDTIME, RDINSTRET）の有効化 |
| `ENABLE_COUNTERS64` | 1 | 64ビット性能カウンタの有効化 |
| `BARREL_SHIFTER` | 0 | バレルシフタの有効化（0: 2ステージシフトによる低面積化） |
| `TWO_CYCLE_ALU` | 0 | ALU演算サイクルの選択（0: 1サイクル実行） |
| `PROGADDR_RESET` | `32'h0000_0000` | リセットベクタアドレス（命令メモリ IMEM の先頭） |
| `STACKADDR` | `32'h0000_0800` | 初期スタックポインタアドレス |

---

## 3. インターフェース仕様 (Port Definitions)

```verilog
module picorv32 #(
    parameter [31:0] PROGADDR_RESET = 32'h 0000_0000,
    parameter [31:0] STACKADDR = 32'h 0000_0800
) (
    input clk,
    input resetn,
    output trap,

    output        mem_valid,
    output        mem_instr,
    input         mem_ready,
    output [31:0] mem_addr,
    output [31:0] mem_wdata,
    output [ 3:0] mem_wstrb,
    input  [31:0] mem_rdata,

    // 割り込みインターフェース
    input  [31:0] irq,
    output [31:0] eoi
);
```

### ポート一覧

| ポート名 | 方向 | ビット幅 | 説明 |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | システムクロック (100 MHz) |
| `resetn` | Input | 1 | アクティブ・ロー・リセット信号 |
| `trap` | Output | 1 | 不正命令または異常停止（トラップ）発生フラグ |
| `mem_valid` | Output | 1 | メモリ・MMIOアクセス要求有効信号 |
| `mem_instr` | Output | 1 | 命令フェッチ要求フラグ（1: 命令, 0: データ） |
| `mem_ready` | Input | 1 | メモリアクセス応答レディ信号 |
| `mem_addr` | Output | 32 | メモリアクセスアドレス |
| `mem_wdata` | Output | 32 | メモリ書き込みデータ |
| `mem_wstrb` | Output | 4 | メモリ書き込みバイトイネーブル（4'b0000: リード） |
| `mem_rdata` | Input | 32 | メモリ読み出しデータ |
| `irq` | Input | 32 | 外部割り込み要求線（bit[0]: 負荷シーケンサステップ遷移割り込み等） |
| `eoi` | Output | 32 | 割り込み処理完了通知（End of Interrupt） |

---

## 4. メモリ・MMIOバスプロトコル

PicoRV32 はシンプルで堅牢なハンドシェイクプロトコルを採用している。
1. **要求フェーズ**:
   - CPUは `mem_valid = 1` をアサートし、`mem_addr`, `mem_wstrb`, `mem_wdata`（ライト時）を駆動する。
   - `mem_instr = 1` は命令メモリフェッチを示し、`mem_instr = 0` はデータロード/ストアまたはMMIOアクセスを示す。
2. **応答フェーズ**:
   - メモリコントローラまたはMMIO周辺回路は、アクセスを完了したサイクルで `mem_ready = 1` を1サイクルアサートする。
   - リードアクセスの場合は、`mem_ready = 1` と同一サイクルで `mem_rdata` にデータを供給する。
3. **完了**:
   - CPUは `mem_ready = 1` を受信した次のクロック立ち上がりで `mem_valid` をデアサートする。

---

## 5. VDRV_v1a システムにおける過渡負荷励起 (Transient Mode)

VDRV_v1a において、CPUは単なる制御装置にとどまらず、動的電流ノイズ源（過渡負荷ジェネレータ）としても活用される。
1. **待機状態（Idle / WFI ループ）**:
   - CPUは低スイッチング状態（割り込み待機ループ）で待機し、消費電流を低水準に保つ。
2. **割り込み駆動による急峻な Wake-up**:
   - 負荷シーケンサがステップ遷移を完了した瞬間、`cpu_irq` パルスが `irq[0]` へ入力される。
   - CPUは即座にパイプラインを再開し、割り込みサービスルーチン（ISR）を実行する。
   - この急峻な状態遷移（Sleep → Active）により、電源配線網に大きな $\frac{di}{dt}$ 過渡電流が発生し、IR-DropおよびLdi/dtノイズ波形の観測が可能となる。
