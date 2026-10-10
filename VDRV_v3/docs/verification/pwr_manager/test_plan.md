# Power Manager (`pwr_manager`) テスト計画書および検証結果

## 1. 検証概要
`pwr_manager` のFSM遷移、投入スケジューラ、MMIOレジスタアクセス、HW-Direct連携、およびUNSAFEモードの全機能を自己検証型テストベンチ（`tb_pwr_manager.v`）を用いて網羅的に検証します。

## 2. 検証環境
- **検証パラメータ**: `G = 4`
- **クロック周期**: 10 ns (100 MHz)
- **パワースイッチモデル**: `vdrv_pwr_switch_model` (Trickle/Main各Ack遅延 `DELAY = 8` サイクル)
- **タイムアウト保護**: 50,000 サイクルで強制終了およびテスト失敗検出

## 3. テスト項目

| テスト番号 | 項目名 | 検証内容 | 期待値・合否判定基準 |
|:---|:---|:---|:---|
| **TEST 1** | リセット値確認 | 非同期リセット解除直後の全出力およびレジスタ値の確認 | `iso_en=4'b1111`, `pd_rst_n=4'b0000`, `sw_trickle_en=0`, `sw_main_en=0`, `pd_on=0`, `PD_STATUS=0` |
| **TEST 2** | 段階的電源投入シーケンス | `STAGGER=20`, `PD_ORDER=0x76543102` で全4グループを投入 | ① 立ち上がり順序が Grp2 → Grp0 → Grp1 → Grp3 であること<br>② 各グループ間の投入間隔が20サイクル以上であること<br>③ 各グループで Trickle から Main まで 16 サイクル以上経過し、かつ Trickle Ack 検出後に Main がアサートされること<br>④ リセット解除（`pd_rst_n=1`）後にアイソレーション解除（`iso_en=0`）されること |
| **TEST 3** | 単一グループ電源遮断 | Grp 1 の電源要求を0にし遮断シーケンスを監視 | ① アイソレーション有効化（`iso_en=1`）→ リセットアサート（`pd_rst_n=0`）→ スイッチ遮断（`sw_en=0`）の順序が厳密に守られること<br>② Grp 1 遮断完了後、他グループ（0, 2, 3）が ON を維持すること |
| **TEST 4** | UNSAFE_MODE 電源投入 | `UNSAFE_MODE=1` を設定し全グループ同時投入 | ① 全要求グループの `sw_trickle_en` と `sw_main_en` が同一サイクルでアサートされること<br>② Ack 待ちを経ずに高速に ON 状態へ遷移すること |
| **TEST 5** | HW-Direct 制御オーバーライド | `hw_direct_active=1` とし `hw_pd_req` を与える | ① `PD_STATUS` の実効要求フィールドに `hw_pd_req` が反映されること<br>② MMIO `PD_REQ` の値に関わらず `hw_pd_req` のマスクに従って電源が制御されること<br>③ `hw_direct_active=0` 復帰時に `PD_REQ` 制御へ正常に戻ること |
| **TEST 6** | MMIO 全レジスタ Readback | 全レジスタへのユニーク値書き込みとリードバック | `PD_REQ`, `T_TRICKLE`, `T_MAIN`, `STAGGER`, `PD_ORDER`, `UNSAFE_MODE`, 未定義アドレス（0x20）のリードバック値が期待値と完全一致すること |

## 4. 検証結果サマリ

| 検証フェーズ | ツール | 条件・対象 | 結果 | 備考 |
|:---|:---|:---|:---:|:---|
| **RTL Lint** | Verilator (v5.032) | `-Wall` (G=1, 2, 4, 8) | **PASS** | エラー・警告ゼロ |
| **Pre-Synthesis Check** | Yosys (v0.52) | `proc; check -assert` | **PASS** | 0 problems reported |
| **Logic Synthesis** | Yosys (v0.52) | ゲートネットリスト生成 | **PASS** | `syn/pwr_manager_gate.v` 生成完了 |
| **Unit Simulation** | Icarus Verilog + VVP | `tb_pwr_manager.v` (G=4) | **PASS** | 全6テスト項目合格 (`TEST PASSED`) |

### シミュレーションログ抜粋
```text
==================================================
[TEST 1] Reset Values Check
==================================================
[PASS] Test 1: Reset values verified.
==================================================
[TEST 2] Safe Power-Up with STAGGER=20 and PD_ORDER=0x76543102
==================================================
  trickle_en rising cycles: Grp0=34, Grp1=54, Grp2=14, Grp3=74
[PASS] Order verified: Grp2 -> Grp0 -> Grp1 -> Grp3.
[PASS] Test 2: Safe power-up sequence verified.
==================================================
[TEST 3] Power-Down of One Group (Grp 1)
==================================================
  Grp 1 power-down timing: iso_assert=121, rst_assert=123, sw_off=125
[PASS] Power-down ordering verified (ISO -> rst -> switch off).
[PASS] Test 3: Power-down of Grp 1 verified.
==================================================
[TEST 4] UNSAFE_MODE=1 Fast Power-Up
==================================================
  Grp 0: tr_rise=148, mn_rise=148
  Grp 1: tr_rise=148, mn_rise=148
  Grp 2: tr_rise=148, mn_rise=148
  Grp 3: tr_rise=148, mn_rise=148
[PASS] All groups received trickle_en and main_en in the same cycle!
[PASS] Test 4: UNSAFE_MODE verified.
==================================================
[TEST 5] HW Direct Active Override (hw_direct_active=1)
==================================================
[PASS] Test 5: hw_direct_active override verified.
==================================================
[TEST 6] MMIO Readback of All Registers
==================================================
[PASS] Test 6: All register readbacks verified.
==================================================
TEST PASSED
```
