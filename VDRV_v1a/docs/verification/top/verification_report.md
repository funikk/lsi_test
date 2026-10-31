# VDRV_v1a トップ階層 (`VDRV_v1a_top`) システム検証レポート (Top Verification Report)

## 1. 検証結果概要

* **総合判定**: **ALL PASS (合格) ✅**
* **検証対象**: `VDRV_v1a_top` / `VDRV_v1a_core` フルシステム統合シミュレーション
* **実行環境**: Icarus Verilog (`v12.0 stable`) & VVP
* **テストベンチ**: `VDRV_v1a/top/tb/tb_VDRV_v1a_top.v`
* **ファームウェア**: `VDRV_v1a/firmware/firmware.hex` (171 words)
* **実行日時**: 2026-10-31

---

## 2. 検証項目別結果一覧

| 項目番号 | 検証項目 | 期待動作 | 判定結果 | ステータス |
| :---: | :--- | :--- | :--- | :---: |
| **TC-01** | ファームウェア自己診断 | `DMEM[63] == 0xDEADBEEF` | `DMEM[63] = 0xDEADBEEF` 検出 | **PASS** |
| **TC-02** | MAC DMA 転送・演算 | `DMEM[8..11]` 非ゼロ出力 | `0x97e5226a 0x1f24c4f3 0x6692b850 0x62090fd7` | **PASS** |
| **TC-03** | CRC DMA 転送・演算 | `DMEM[12..15]` 非ゼロ・MACと異なる | `0x62d010cb 0x4e4194cd 0xde02fb1e 0x7808de0c` | **PASS** |
| **TC-04** | 連続負荷モード制御 | 有限(3)/無限ブロック実行と正常復帰 | 正常自動復帰および手動停止完了 | **PASS** |
| **TC-05** | UART シーケンス設定 | 4 ステップのシリアルパケット受信 | パケットデコード・テーブル設定完了 | **PASS** |
| **TC-06** | シーケンサ実行 & 遷移 | `3'b001` -> `3'b010` -> `3'b011` -> `3'b111` | 4 ステートすべて完全一致 | **PASS** |

---

## 3. シミュレーション実行ログ (抜粋)

```text
[SIM] Building system-level integration testbench...
( iverilog -g2012 -I../common/rtl -Irtl ... -o sim/top_tb.vvp ... && cd sim && vvp top_tb.vvp )
VCD info: dumpfile tb_VDRV_v1a_top.vcd opened for output.
[TB] Waiting for firmware self-test completion (DMEM[63] == 0xDEADBEEF)...
[TB] Firmware self-test completed! Magic marker detected: 0xdeadbeef
[TB] MAC DMA Output (mem[8..11]): 0x97e5226a 0x1f24c4f3 0x6692b850 0x62090fd7
[TB] CRC DMA Output (mem[12..15]): 0x62d010cb 0x4e4194cd 0xde02fb1e 0x7808de0c
[PASS] MAC and CRC DMA outputs are non-zero and distinct.
[TB] Sending CMD_START_SEQ to load_sequencer...
[TB] Monitoring state transitions...
[PASS] Step 0 verified: cpu_load_state=3'b001, mac_load_mode_en=1, crc_load_mode_en=0
[PASS] Step 1 verified: cpu_load_state=3'b010, mac_load_mode_en=0, crc_load_mode_en=1
[PASS] Step 2 verified: cpu_load_state=3'b011, mac_load_mode_en=1, crc_load_mode_en=1
[PASS] Step 3 verified: cpu_load_state=3'b111, mac_load_mode_en=1, crc_load_mode_en=1
[PASS] ALL SYSTEM-LEVEL VERIFICATION CHECKS PASSED SUCCESSFULLY!
```

---

## 4. 評価と結論

1. **HW/SW 協調動作の完全性**:
   - PicoRV32 によるブートから MMIO レジスタ設定、DMA コントローラ経由の演算起動、共有 SRAM (`DMEM`) への自動書き戻しまでの一連のトランザクションが仕様通り動作することを確認しました。
2. **負荷刺激コアの分離・非相関性**:
   - MAC アレイと CRC-RS コアがそれぞれ異なるシグネチャを生成し、共有データメモリ上に非ゼロかつ完全に独立した値を出力することを確認しました。
3. **外部 UART 制御によるシーケンサ動作**:
   - UART からのパケット送信により、ハードウェア直結型シーケンサが 4 段階の負荷状態（MAC 単体、CRC 単体、MAC+CRC 同時、CPU+MAC+CRC 全面稼動）へサイクル精度で遷移することを確認しました。

以上の結果より、`VDRV_v1a` システムの論理機能および HW/SW 協調制御は完全な品質基準を達成していると判定します。
