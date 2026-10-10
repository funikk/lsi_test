# Load Sequencer モジュール テスト計画書 (VDRV_v3)

## 1. 概要

本ドキュメントは、VDRV_v3 システムの `load_sequencer` モジュールに対する機能検証およびサイクル精度検証の計画を示す。
テストベンチは完全自己検証型（Self-checking）とし、期待値との比較を行い、成功時に `TEST PASSED`、失敗時に `TEST FAILED` を出力して終了する。

---

## 2. 検証項目一覧

| 項目ID | 検証カテゴリ | 検証内容 | 合否判定基準 |
| :--- | :--- | :--- | :--- |
| **TC-01** | リセット動作 | リセット解除時の初期状態確認 | `running=0`, `seq_done=0`, `hw_direct_active=0`, `seq_pg_sync=0`, `cpu_irq=0`, `cur_step=0` |
| **TC-02** | MMIO設定とリードバック | `STEP_W0`, `STEP_W1`, `SEQ_CTRL`, `SEQ_STATUS` のアクセス検証 | 設定値と完全一致。未定義アドレスへのアクセスで `32'h0` 応答 |
| **TC-03** | ONESHOT サイクル精度実行 | 3ステップ設定時の各ステップ継続時間および出力値検証 | 各ステップ長が厳密に $(DURATION + 1) \times (TICK\_DIV + 1)$ サイクルであること。<br>`cur_*` が各ステップの設定値を出力すること |
| **TC-04** | 同期パルス (`seq_pg_sync`) | 各ステップ開始時のパルス発生検証 | ステップ0開始時を含む各ステップ先頭サイクルで厳密に1サイクルパルスが出力されること |
| **TC-05** | ONESHOT 完了シーケンス | 最終ステップ終了時の完了処理確認 | `running=0`, `seq_done=1`, `hw_direct_active=0` となり、`cur_*` の値が維持されること |
| **TC-06** | ループ実行 (`ONESHOT=0`) | 最終ステップ終了後のラップアラウンド検証 | ステップ0へ復帰し `running=1`, `seq_done=0` を維持すること。復帰時に `seq_pg_sync` がパルス出力されること |
| **TC-07** | MMIO 停止機能 | 実行中の `SEQ_ENABLE=0` 書き込みによる停止 | 直後のサイクルで `running=0` となり、シーケンスが停止すること |
| **TC-08** | IRQ モード (`IRQ_MODE=1`) | 割り込みパルス出力および直接制御抑止 | `hw_direct_active=0` が維持されること。<br>ステップ遷移時および完了時に `cpu_irq` が1サイクルパルス出力されること |
| **TC-09** | UART `cmd_set_step` | UARTからのステップ部分書き換え検証 | `DURATION` および `PROFILE_ID` のみが更新され、`MARKER`, `EM_CTRL`, `PD_REQ` が保持されること |
| **TC-10** | UART START/STOP | UARTコマンドによる起動・停止検証 | `cmd_start_seq` でステップ0から開始、`cmd_stop_seq` で停止すること |
| **TC-11** | タイムアウト保護 | 異常時のハング防止 | 50us (5000サイクル) でタイムアウトし `TEST FAILED` で終了すること |

---

## 3. テストベンチ設計

- **対象ファイル**: `blocks/load_sequencer/tb/tb_load_sequencer.v`
- **クロック設定**: 100 MHz (周期 10ns, `#5 clk = ~clk`)
- **シミュレーション高速化**: `TICK_DIV = 3` (1 tick = 4 クロックサイクル) を使用し、テスト時間を短縮しながら全サイクル精度を検証。
- **実行手順**:
  ```bash
  make -C blocks/load_sequencer unit_sim
  ```
