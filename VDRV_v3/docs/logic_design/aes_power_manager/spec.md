# AES Power Manager仕様書

## 1. 概要

`aes_power_manager` は常時給電ドメインに配置され、AES/PRNG演算ドメイン
`PD_AES` のRTL電源状態を制御する。物理power switchやUPFセルは対象外である。

## 2. MMIO

| アドレス | レジスタ | 内容 |
| --- | --- | --- |
| `0x8000_0200` | `PWR_CTRL` | bit[0]: `AES_PWR_REQ` (1: ON要求、0: OFF要求) |
| `0x8000_0204` | `PWR_STATUS` | bit[0]: 要求、bit[1]: 電源ON、bit[2]: 遷移中、bit[3]: isolation、bit[4]: AES idle、bit[7:5]: 状態 |

HW-Direct ModeではLoad Sequencerの要求がMMIO要求より優先される。

## 3. 動作

OFF時はAES/PRNG内部状態を保持しない。OFF要求では進行中DMA/AESを完了して
`aes_idle` を確認した後にisolationしてOFFへ遷移する。`POWER_AWARE_SIM` 定義時、
OFF中のPD_AES生出力はXとなるが、AON側isolation出力は0へクランプされる。
