# VDRV_v1 Load Sequencer仕様書

## 1. 概要
Load Sequencerは、VDRV_v1システム内で規定された負荷パターン(シーケンス)を自律的かつ高精度に生成するためのハードウェアモジュールである。

## 2. タイムベース設計 (Tick Timer)
シーケンスの継続時間を管理するための基準となるTick Timerを内蔵する。
- **システムクロック**: 100 MHz (1周期 10ns)
- **1 Tickの長さ**: 0.5 us (500 ns)
- **Tick生成カウント数**: 50 サイクル (10ns * 50 = 500ns = 0.5us)
各シーケンスステップのDurationは、このTick数を単位として16ビットで指定される(最大 65535 Tick ≒ 32.7ms)。

## 3. シーケンスメモリマップおよびレジスタ定義
Load Sequencerは最大16ステップのシーケンスを保持できる。
MMIO空間 (`0x8000_0100 - 0x8000_0140`) 上に以下のレジスタがマッピングされる(ベースアドレスからのオフセットで表記)。

| オフセット | レジスタ名 | 属性 | 説明 |
| :--- | :--- | :--- | :--- |
| `0x00` | `SEQ_CTRL` | R/W | シーケンサ制御。<br>bit[0]: START/STOP<br>bit[1]: IRQ_MODE設定 (0: HW-Direct, 1: CPU-IRQ Transient) |
| `0x04` | `SEQ_STATUS` | R/O | 現在のステータス。<br>bit[3:0]: Current Step ID<br>bit[5:4]: Current State<br>bit[31:16]: Remaining Ticks |
| `0x10`+(`4*i`) | `STEP_REG[i]` | R/W | Step `i` の設定 (i = 0～15)。<br>bit[17:16]: State (00=IDLE, 01=AES_FULL, 10=CPU_FULL, 11=BOTH_FULL)<br>bit[15:0]: Duration Ticks |

*(注: UARTからもコマンド経由で設定可能)*

## 4. デュアルモード・ハイブリッド動作 (Candidate C)
Load Sequencerは、負荷変動時のdi/dtノイズ解析や電力評価のため、以下の2つの動作モードをサポートする。動作モードは `SEQ_CTRL` レジスタの `IRQ_MODE` ビットによって選択される。

### 4.1 IRQ_MODE = 0 (HW-Direct Mode)
CPUの割り込み(ISR)を介さずに、Load Sequencer自身がサイクル精度のハードウェア自律制御を行う。
- メリット: CPUの割り込み処理に伴うノイズ(ISR noise)が一切発生せず、純粋なAESや他モジュールの負荷状態遷移のみを観測・評価できる。
- 動作: ステップ遷移時、直接AES_DMAやCPUのハードウェア制御信号を駆動する。

### 4.2 IRQ_MODE = 1 (CPU-IRQ Transient Mode)
ステップ遷移が発生するタイミングで、CPUに対して `irq` (割り込み要求) をアサートする。
- メリット: CPUがスリープ/アイドル状態からウェイクアップする際の過渡的な負荷変動($di/dt$ CPU wake-up transients)を意図的に引き起こし、システム全体の過渡応答を評価できる。
- 動作: ステップのTickカウンタが0になり次のステップへ遷移する際、CPUに割り込み信号パルスを出力する。
