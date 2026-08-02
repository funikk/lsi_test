# AES-DMA サブシステム仕様書 (VDRV_v2)

## 1. 流用情報 (Reused Module Origin)
* **流用元プロジェクト**: `cpu_aes_prng_test` (`cpu_aes_prng_test/rtl/aes_dma_subsys.v`)
* **仕様概要**: PicoRV32 CPU のバスマスターと調停し、Shared DMEM 上で AES 暗号化および PRNG データを高速 DMA 転送するサブシステム。

## 2. メモリマップ & MMIO
* MMIO アドレス範囲: `0x8000_0000 - 0x8000_0048`
* 機能: DMA 転送制御、AES モード切替、キー/シード設定。

## 3. PD_AESとの接続

AES-DMAのMMIOレジスタ、DMA FSM、ローカルバッファは常時給電側に残す。
AES coreとPRNGは `PD_AES` に含め、`aes_power_ready` が0の間はDMA開始と
PRNG seedロードを受理しない。開始要求が不可能なときはSTATUS bit[3]
(`POWER_UNAVAILABLE`) をセットする。電源OFF要求中は新規処理を止め、
`aes_idle` をPower Managerへ返す。

## 4. Load Sequencer直結制御

`load_sequencer` がHW-Direct Modeで実行中である間、`hw_load_mode_en` が
ソフトウェアの `REG_CTRL[1]` (`LOAD_MODE_EN`) より優先される。これにより、
HW-Direct
Mode の `AES_FULL` / `BOTH_FULL` ステップではAES/PRNG連続負荷を有効化し、
`IDLE` / `CPU_FULL` ステップでは停止できる。シーケンサ停止後は、従来どおり
`REG_CTRL[1]` の設定がload modeを制御する。CPU-IRQ Modeでは、シーケンサは
直接制御を行わず、CPUが割り込み処理で `REG_CTRL[1]` を更新する。
