# VDRV_v2 ファームウェア仕様書

## 1. 概要 (Overview)
本ドキュメントは、VDRV_v2環境におけるファームウェア（FW）の設計仕様を定義する。
ファームウェアの主な役割は以下の通りである。
* VDRV_v2の負荷状態（Load State）とPD_AES電源状態の制御・監視。
* AES-DMAの起動および乱数生成器（PRNG）の制御。
* 割込み（Interrupt）の適切なハンドリング。

## 2. メモリマップ & MMIO定義 (Memory Map & MMIO)

### 2.1 Shared DMEM
共有データメモリ（DMEM）はアドレス `0x0000_0000` に配置される。
スタック領域、平文・暗号文のバッファ、PRNGデータの格納場所として使用される。

### 2.2 AES-DMA MMIO
AES-DMAモジュールの制御レジスタは `0x8000_0000` から `0x8000_0048` の領域にマッピングされている。
* `0x8000_0000` : `REG_CTRL` (コントロール)
* `0x8000_0004` : `REG_STATUS` (ステータス)
* `0x8000_0010` - `0x8000_001C` : `REG_KEY(0..3)` (128-bit 鍵設定)
* `0x8000_0020` - `0x8000_002C` : `REG_SEED(0..3)` (128-bit PRNG シード設定)
* `0x8000_0030` - `0x8000_003C` : `REG_PRNG_DATA(0..3)` (PRNG 出力データ)
* `0x8000_0040` : `REG_SRC_ADDR` (DMA 送信元アドレス)
* `0x8000_0044` : `REG_DST_ADDR` (DMA 宛先アドレス)
* `0x8000_0048` : `REG_LEN` (DMA ブロック数)

### 2.3 Load Sequencer制御
Load SequencerのCPU MMIOは `0x8000_0100` の `SEQ_CTRL` のみである。
UARTの `SET_STEP` / `START_SEQ` / `STOP_SEQ` コマンドはUARTピンから入力する。
`cpu_load_state` と `aes_load_mode_en` はトップレベル観測出力であり、CPU読み出し用の
`REG_LOAD_STATE` はRTLに実装されていない。

### 2.4 AES Power Manager MMIO

AES/PRNG電源モデルの制御レジスタは `0x8000_0200` から `0x8000_0204` にある。
* `0x8000_0200` : `REG_PWR_CTRL` (bit[0]: AES電源ON要求)
* `0x8000_0204` : `REG_PWR_STATUS` (bit[1]: 電源ON、bit[2]: 遷移中、bit[3]: isolation)

AES/PRNGを使用する前に、FWは `REG_PWR_CTRL=1` を書き、`REG_PWR_STATUS[1]`
が1になるまで待機する。利用後は `REG_PWR_CTRL=0` を書き、電源OFFを確認する。
電源遮断後はAES/PRNGの内部状態が失われるため、次回利用時に鍵とseedを再設定する。

## 3. 割込み処理フロー (Interrupt Handling Flow)

割込みが発生した場合、ファームウェアは以下の手順で処理を実行する。
1. **割込みベクタ**:
   `start.S` にて、アドレス `0x0000_0010` (`irq_entry`) が割込みエントリポイントとして定義されている。
2. **コンテキストの退避と復帰**:
   割込みハンドラ進入時に汎用レジスタをスタックに退避し、復帰時にリストアする。
   PicoRV32固有の仕様として、割込みからのリターンアドレスは `x3` (`q3` または `gp`) に格納されているため、`jalr x0, x3, 0` によって元の処理へ復帰する。
3. **C関数の呼び出し**:
   コンテキスト退避後、`main.c` に定義された `irq_handler()` が呼び出され、具体的な割込み処理を行う。

## 4. メインループ動作 (Main Loop Execution)

初期化および電源遮断テスト後、ファームウェアはCPU状態MMIOを使用せず、軽量な
`nop` ループを実行する。CPU負荷状態の切り替えはVDRV_v2ではトップ出力の観測対象であり、
CPU自身の動作モードを変更する機能は含まれない。

## 5. ビルド・コンパイル手順 (Build Instructions)

ファームウェアはRISC-V 32-bit (rv32i) 向けにコンパイルされる。
* **GCC フラグ**:
  `-march=rv32i -mabi=ilp32 -Os -fno-delete-null-pointer-checks -ffreestanding -nostdlib`
  ベアメタル環境向けに標準ライブラリを使用せず、最適化 (`-Os`) を有効化している。
* **リンカスクリプト**:
  `sections.lds` を使用し、テキスト領域およびデータ領域をメモリマップに基づいて適切に配置する（`.text.start` は `0x0000_0000` のエントリポイント）。
* **バイナリ生成手順**:
  `make` を実行すると、`firmware.elf` が生成され、`objcopy` によって `firmware.bin` (ベタバイナリ) に変換される。
  その後、Pythonスクリプト `bin2hex.py` によりシミュレーション用のHEXファイル (`firmware.hex`) が生成される。
