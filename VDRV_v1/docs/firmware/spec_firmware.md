# VDRV_v1 ファームウェア仕様書

## 1. 概要 (Overview)
本ドキュメントは、VDRV_v1環境におけるファームウェア（FW）の設計仕様を定義する。
ファームウェアの主な役割は以下の通りである。
* VDRV_v1の負荷状態（Load State）の制御と監視。
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

### 2.3 UART & Load Sequencer MMIO
UARTおよびロードシーケンサの制御レジスタは `0x8000_0100` から `0x8000_0108` の領域にマッピングされている。
* `0x8000_0100` : `REG_UART_TX`
* `0x8000_0104` : `REG_UART_RX`
* `0x8000_0108` : `REG_LOAD_STATE` (現在の負荷状態を示す)

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

初期化およびテスト実行後、ファームウェアは無限ループにて `0x8000_0108` の `REG_LOAD_STATE` をポーリングする。

* **高負荷時 (`CPU_FULL`: 1 または `BOTH_FULL`: 3)**:
  状態が `LOAD_STATE_CPU_FULL` (0x01) または `LOAD_STATE_BOTH_FULL` (0x03) の場合、プロセッサは高電力消費状態を模擬するための Intensive な ALU 演算およびメモリアクセスループを実行する。
* **低負荷時 (`IDLE`: 0 または `AES_FULL`: 2)**:
  状態が `LOAD_STATE_IDLE` (0x00) または `LOAD_STATE_AES_FULL` (0x02) の場合、`nop` 命令を使用した軽量なポーリングループ（Low-power wait）を実行する。

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
