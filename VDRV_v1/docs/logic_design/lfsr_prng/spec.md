# LFSR PRNG モジュール仕様書 (流用ブロック)

## 1. 流用情報 (Reused Module Origin)
* **流用元プロジェクト**: `aes_prng_test` (`aes_prng_test/rtl/lfsr_prng.v`)
* **仕様概要**: 32-bit ガロア型線形帰還シフトレジスタ (LFSR) による疑似乱数生成器。

## 2. VDRV_v1 での役割
* AES 暗号コアの入力平文データバッファに対する連続的疑似乱数入力シードの供給。
