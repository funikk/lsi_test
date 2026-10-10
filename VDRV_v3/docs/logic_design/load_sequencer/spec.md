# Load Sequencer モジュール仕様書 (VDRV_v3)

## 1. 概要

`load_sequencer` は、VDRV_v3 システム内において負荷タイルアレイ（`load_tile`）、EMストレスブロック（`em_stress`）、および電源マネージャ（`pwr_manager`）へ向けた自律的かつ高精度（サイクル単位）な負荷シーケンスおよび同期パルスを生成するモジュールである。

VDRV_v2 からの改定点：
- MMIO スレーブアドレスが 8 ビットのブロック内オフセット形式に変更（トップレベルでアドレスデコードを実施）。
- 負荷対象が VDRV_v2（CPU/AES）から負荷タイルアレイプロファイル（`PROFILE_ID`）、電源要求（`PD_REQ`）、観測用マーカー（`MARKER`）、EMストレス制御（`EM_CTRL`）へと拡張。
- 1ステップあたり 2 ワード（`STEP_W0`, `STEP_W1`）のレジスタマップを採用し、最大16ステップの自律シーケンスを管理。
- 最終ステップ完了後の自動停止（`ONESHOT` モード）および完了フラグ（`seq_done`）を追加。
- ステップ開始ごとの1サイクル同期パルス（`seq_pg_sync`）を出力。
- 旧出力ポート `aes_load_mode_en` および `cpu_load_state` を削除。

---

## 2. ポート一覧

| ポート名 | 方向 | 幅 | 説明 |
| :--- | :---: | :---: | :--- |
| `clk` | input | 1 | システムクロック（立ち上がりエッジ） |
| `rst_n` | input | 1 | 非同期アクティブローリセット |
| **UART インターフェース** | | | |
| `cmd_set_step` | input | 1 | UARTステップ設定ストローブ |
| `cmd_start_seq` | input | 1 | UARTシーケンス開始要求 |
| `cmd_stop_seq` | input | 1 | UARTシーケンス停止要求 |
| `step_id` | input | 4 | 設定対象ステップ番号 (0〜15) |
| `step_state` | input | 2 | `PROFILE_ID` 設定値 |
| `step_duration` | input | 16 | `DURATION` 設定値 |
| **MMIO スレーブインターフェース** | | | |
| `mmio_valid` | input | 1 | MMIO アクセス有効（アドレスデコード済み） |
| `mmio_addr` | input | 8 | ブロック内バイトオフセット（下位2bitは常に0） |
| `mmio_wstrb` | input | 4 | バイト書き込みストローブ（0: 読み出し、非0: 書き込み） |
| `mmio_wdata` | input | 32 | 書き込みデータ |
| `mmio_rdata` | output | 32 | 読み出しデータ（レジスタ出力） |
| `mmio_ready` | output | 1 | MMIO 応答準備完了（1サイクルパルス） |
| **制御・ステータス出力** | | | |
| `hw_direct_active` | output | 1 | ハードウェア直接制御有効（`running && !irq_mode`） |
| `running` | output | 1 | シーケンサ実行中フラグ（FF出力） |
| `seq_done` | output | 1 | ONESHOT完了フラグ（最終ステップ終了で1、再起動で0） |
| `seq_pg_sync` | output | 1 | 各ステップ開始時の1サイクルパルス |
| `cur_profile_id` | output | 2 | 現在のタイルプロファイル番号 (0〜3) |
| `cur_pd_req` | output | 8 | 現在の電源ドメイン要求ビットマップ |
| `cur_marker` | output | 2 | 現在の観測マーカー値 (0〜3) |
| `cur_em_ctrl` | output | 3 | 現在のEMストレス制御信号 |
| `cur_step` | output | 4 | 現在実行中のステップ番号 (0〜15) |
| `cpu_irq` | output | 1 | ステップ遷移時および完了時割り込みパルス（`irq_mode` 時のみ） |

---

## 3. レジスタマップ

MMIO アドレス空間（8ビットオフセット、`0x00`〜`0xBC`）にマッピングされる。

| オフセット | レジスタ名 | 属性 | リセット値 | ビット定義および説明 |
| :--- | :--- | :---: | :---: | :--- |
| `0x00` | `SEQ_CTRL` | RW | `0x0031_0000` | [0] `IRQ_MODE` (0: HW-Direct, 1: CPU-IRQ)<br>[1] `SEQ_ENABLE` (1: 開始/有効, 0: 停止)<br>[2] `ONESHOT` (0: ループ実行, 1: ワンショット実行)<br>[7:4] `TOTAL_STEPS` (最終ステップ番号、0〜15)<br>[31:16] `TICK_DIV` (1 tick あたりのクロック数 - 1、リセット値 49 = 50サイクル) |
| `0x04` | `SEQ_STATUS` | R | `0x0000_0000` | [0] `running`<br>[1] `seq_done`<br>[7:4] `cur_step` |
| `0x40 + 8s` | `STEP_W0[s]` | RW | `0x0000_0000` | ステップ $s$ 設定ワード0 ($s \in 0..15$)<br>[15:0] `DURATION` (継続 tick 数 - 1)<br>[17:16] `PROFILE_ID` (タイルプロファイル 0〜3)<br>[21:20] `MARKER` (観測用マーカー 0〜3)<br>[26:24] `EM_CTRL` (EMストレス制御) |
| `0x44 + 8s` | `STEP_W1[s]` | RW | `0x0000_0000` | ステップ $s$ 設定ワード1 ($s \in 0..15$)<br>[7:0] `PD_REQ` (電源ドメイン要求ビットマップ) |

未定義のオフセットへのアクセスは、読み出しで `32'h0` を返し、書き込みは無視される。

---

## 4. 動作詳細

### 4.1 シーケンスの開始と停止

- **開始条件**:
  `SEQ_ENABLE` が 0→1 に遷移したサイクル、または未実行時（`!running`）に `SEQ_ENABLE=1` が書き込まれたサイクル、あるいは UART から `cmd_start_seq` パルスを受信したサイクル。
  - 開始したサイクルで `running <= 1`, `seq_done <= 0` となり、ステップ0の値が `cur_*` に即座に反映される。
  - 同時に `seq_pg_sync` が1サイクルパルスとして出力される。
- **停止条件**:
  `SEQ_ENABLE` を 0 に書き込んだサイクル、または UART から `cmd_stop_seq` パルスを受信したサイクル。
  - `running <= 0` となり、シーケンスの進行が直ちに停止する（`cur_*` の値は保持される）。

### 4.2 タイムベースとステップ進行

- **1 Tick の長さ**: `(TICK_DIV + 1)` クロックサイクル。
- **ステップの継続時間**: `(DURATION + 1)` tick。
  したがって、1ステップあたりの総サイクル数は厳密に以下となる：
  $$\text{Cycles} = (\text{DURATION} + 1) \times (\text{TICK\_DIV} + 1)$$
- 各ステップが開始する最初のクロックサイクルにおいて、`seq_pg_sync` が 1 サイクルパルスとして出力される（ステップ0の開始時を含む）。
- ステップの時間が満了すると、次のステップ（`cur_step + 1`）へ移行し、`cur_*` の値が更新され、再び `seq_pg_sync` が 1 サイクルパルス出力される。

### 4.3 シーケンス完了とループ動作

ステップ `TOTAL_STEPS` の時間が満了したときの動作は、`ONESHOT` ビットの設定に依存する。

- **ONESHOT = 0 (ループモード)**:
  - 最終ステップ終了後、自動的にステップ 0 へラップアラウンドする。
  - `running` は 1 を維持し、`seq_done` は 0 のままである。
  - ステップ 0 への復帰サイクルで `seq_pg_sync` が出力される。
- **ONESHOT = 1 (ワンショットモード)**:
  - 最終ステップ終了後、`running <= 0`, `seq_done <= 1` となる。
  - `cur_*` および `cur_step` は最終ステップの値をそのまま保持する。
  - `seq_pg_sync` は出力されない。

### 4.4 割り込みモード (`IRQ_MODE`)

- **IRQ_MODE = 0 (HW-Direct Mode)**:
  - `hw_direct_active = running` となり、ハードウェア（タイルや EM ストレス）が自律駆動される。
  - `cpu_irq` はアサートされない（常に 0）。
- **IRQ_MODE = 1 (CPU-IRQ Transient Mode)**:
  - `hw_direct_active = 0` となり、CPU が MMIO を介して手動でモード変更やウェイクアップ過渡現象をテストできるよう制御権を保持する。
  - ステップ間の遷移タイミング（ステップ $k \rightarrow k+1$、またはラップアラウンド時、または ONESHOT 完了時）において、`cpu_irq` が 1 サイクルパルス出力される。

### 4.5 UART インターフェース連携

- UART パネル経由での動的設定をサポートする。
- `cmd_set_step` の受信時：
  - 対象ステップ `step_id` の `DURATION` を `step_duration` に更新する。
  - 対象ステップ `step_id` の `PROFILE_ID` を `step_state` に更新する。
  - 当該ステップの `MARKER`, `EM_CTRL`, `PD_REQ` は変更されず維持される。
- `cmd_start_seq` / `cmd_stop_seq`:
  - それぞれシーケンスの開始（ステップ0から）および停止を行う。
