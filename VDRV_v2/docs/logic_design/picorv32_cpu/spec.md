# PicoRV32 CPU モジュール仕様書 (流用ブロック)

## 1. 流用情報 (Reused Module Origin)
* **流用元プロジェクト**: `cpu_aes_prng_test` (`cpu_aes_prng_test/rtl/picorv32.v`)
* **仕様概要**: Claire Wolf 氏開発の RV32I / RV32E オープンソース RISC-V プロセッサコア。

## 2. VDRV_v2 でのパラメータ設定
* `ENABLE_IRQ = 1`: ハードウェア割り込み制御を有効化
* `ENABLE_IRQ_QREGS = 1`: 割込みコンテキスト退避用 `q` レジスタを有効化
* `ENABLE_IRQ_TIMER = 1`: PicoRV32 内部タイマー割り込みを有効化
* `BARREL_SHIFTER = 1`: バレルシフタハードウェア有効化

## 3. インターフェース
* 命令バス (IMEM): `mem_instr`, `mem_addr`, `mem_rdata`, `mem_ready`
* データバス (DMEM): `mem_valid`, `mem_wstrb`, `mem_addr`, `mem_wdata`, `mem_rdata`, `mem_ready`
* 割込み入力: `irq[31:0]` (`irq[3]` が `load_sequencer` に接続)
