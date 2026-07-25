# AES 128-bit Core モジュール仕様書 (流用ブロック)

## 1. 流用情報 (Reused Module Origin)
* **流用元プロジェクト**: `aes_prng_test` (`aes_prng_test/rtl/aes_core.v`)
* **仕様概要**: NIST FIPS-197 準拠 128-bit AES (Advanced Encryption Standard) 暗号ハードウェアコア。

## 2. VDRV_v1 での役割
* 電源電圧ドロップ（IR-Drop）を擬似発生させる高スイッチング周波数パターン生成源。
* `aes_dma_subsys` の内部暗号エンジンとして透過的連続モード（Continuous PRNG Mode）で動作。
