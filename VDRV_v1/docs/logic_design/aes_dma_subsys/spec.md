# AES-DMA サブシステム仕様書 (流用ブロック)

## 1. 流用情報 (Reused Module Origin)
* **流用元プロジェクト**: `cpu_aes_prng_test` (`cpu_aes_prng_test/rtl/aes_dma_subsys.v`)
* **仕様概要**: PicoRV32 CPU のバスマスターと調停し、Shared DMEM 上で AES 暗号化および PRNG データを高速 DMA 転送するサブシステム。

## 2. メモリマップ & MMIO
* MMIO アドレス範囲: `0x8000_0000 - 0x8000_0048`
* 機能: DMA 転送制御、AES モード切替、キー/シード設定。
