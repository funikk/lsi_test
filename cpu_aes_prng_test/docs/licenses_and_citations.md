# 外部引用回路およびライセンス仕様書 (`licenses_and_citations.md`)

本ドキュメントは、[cpu_aes_prng_test](../) プロジェクトで引用・使用している外部オープンソース IP 回路の引用元、著作権者、および適用ライセンス条件を記録した参照書です。

---

## 1. モジュール別ライセンス概要一覧

| モジュール名 | ファイルパス | 引用元 / 原作者 | ライセンス種別 | 商用利用 / 改変 |
| :--- | :--- | :--- | :--- | :--- |
| **PicoRV32** | [rtl/picorv32.v](../rtl/picorv32.v) | Claire Xenia Wolf (<claire@yosyshq.com> / YosysHQ)<br>[YosysHQ/picorv32](https://github.com/YosysHQ/picorv32) | **ISC License** | **許可** (無制限) |
| **AES-128 Core & S-Box** | [rtl/aes_core.v](../rtl/aes_core.v)<br>[rtl/aes_sbox.v](../rtl/aes_sbox.v) | NIST FIPS-197 準拠オープンソース参考設計 | **Public Domain / Permissive** | **許可** (無制限) |

---

## 2. 外部引用モジュールの詳細とライセンス本文

### 2.1 PicoRV32 32-bit RISC-V CPU Core (`picorv32.v`)

- **引用元 URL**: [https://github.com/YosysHQ/picorv32](https://github.com/YosysHQ/picorv32)
- **著作権表示**: Copyright (C) 2015 Claire Xenia Wolf <claire@yosyshq.com>
- **適用ライセンス**: **ISC License**

#### ISC ライセンス全文 (日本語訳付)

> **Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.**
>
> **THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.**

*(訳文: 上記の著作権表示および本許諾表示がすべての複製に含まれる限り、有償か無償かを問わず、目的の如何を問わず、本ソフトウェアを使用、複製、改変、および/または配布する許可がここに付与されます。本ソフトウェアは「現状のまま」提供され、作者は履行保証や適合性保証を含む一切の保証を無効とします。)*

---

### 2.2 AES-128 暗号化コア & S-Box (`aes_core.v`, `aes_sbox.v`)

- **規格基準**: 米国標準技術研究所 NIST FIPS-197 Advanced Encryption Standard (AES)
- **回路アーキテクチャ**: 20 パラレル S-Box 割り当て 12 クロックサイクル・イテレーティブ暗号化構造
- **適用ライセンス**: **Public Domain / Permissive (MIT・Apache 2.0 互換)**
- **利用条件**: 学術研究、論文発表、FPGA/ASIC 評価、および製品組み込みにおいて、何らの制限なく利用・再配布が可能です。

---

## 3. コンプライアンスに関する注意事項

1. **著作権表示の維持**: `rtl/picorv32.v` のファイル先頭にある著作権表示および ISC ライセンスヘッダは改変せず保持されています。
