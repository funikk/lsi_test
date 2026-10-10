# VDRV_v2 Load Sequencer仕様書

## 1. 概要
Load Sequencerは、VDRV_v2システム内で規定された負荷パターン(シーケンス)を自律的かつ高精度に生成するハードウェアモジュールである。HW-Direct ModeではAES負荷要求がPD_AES電源要求としてPower Managerへ伝達される。

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
| `0x00` | `SEQ_CTRL` | R/W | bit[0]: `IRQ_MODE` (0: HW-Direct, 1: CPU-IRQ)、bit[1]: `SEQ_ENABLE`、bit[7:4]: `TOTAL_STEPS` |

ステップ内容（状態・期間）はUARTの `SET_STEP` コマンドで設定する。RTLには
CPU MMIO経由の `SEQ_STATUS` / `STEP_REG` は実装されていない。現在の状態は
トップ出力 `cpu_load_state`、AES負荷要求は `aes_load_mode_en` で観測する。

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
