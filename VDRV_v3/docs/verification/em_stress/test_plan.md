# EM Stress Block (`em_stress`) テスト計画書および検証結果

## 1. 検証概要
`em_stress` ブロックの広幅トグルバス動作（パターン0トグル、パターン1 LFSR）、受信FFの1サイクル追従、高ファンアウト網のトグルおよび停止（static）動作、MISRシグネチャ（`EM_SIG`）の更新と安定性、Load Sequencerからのハードウェア直接制御オーバーライド、および論理合成でのシンクFF非併合（DFF数）を検証する。

## 2. 検証項目
1. **静的検証 (Lint)**
   - Verilator (`-Wall`) による静的解析（警告0件）。
2. **前合成チェック (Presynth Check)**
   - Yosys による `proc; check -assert` 実行。意図しないラッチや組合せループがないこと。
3. **論理合成・DFF併合防止確認 (Yosys Synth)**
   - `yosys -p "read_verilog ...; synth -top em_stress; stat"` を実行。
   - `FANOUT` 個（64個）のシンクFFが `opt_merge` 等で併合されず独立して保持されていることを確認。
   - 全体DFF数が仕様目標 $W \times 2 + \text{FANOUT} + 1 = 32 \times 2 + 64 + 1 = 129$ 以上であることを確認。
4. **機能検証 (Unit Sim)**
   - リセット時、`u_tx.tx_data` が `0101…`（`0x55555555`）で初期化され、`u_rx.rx_data` が0に初期化されること。
   - `bus_en=1`, `pattern=0` のとき、毎サイクル全ビットが反転し、`rx_data` が1サイクル遅延して追従すること。
   - `bus_en=1`, `pattern=1` のとき、LFSRにより擬似ランダムに値が変化し、`rx_data` が1サイクル遅延して追従すること。
   - 全無効化（`bus_en=0`, `fo_en=0`）時、TX、RX、ファンアウト網、および `EM_SIG` が完全に静止（static）すること。
   - `fo_en=1` 有効時、`src` が毎サイクル反転し、`sink` がトグル動作すること。また `EM_SIG` が毎サイクル更新されること。
   - `hw_direct_active=1` 時、MMIO設定値を無視して `hw_em_ctrl` の制御が最優先で反映されること。

## 3. テストベンチ構成
- テストベンチファイル: `tb/tb_em_stress.v`
- 自己判定機能: 全チェック通過時に `TEST PASSED`、不一致時に `TEST FAILED` を出力。
- ウォッチドッグタイマ: 50µsでタイムアウト。

## 4. 検証結果
- **Verilator Lint**: PASSED (警告0件)
- **Pre-synthesis Check**: PASSED (0 problems reported)
- **単体シミュレーション (unit_sim)**: PASSED (`TEST PASSED`)
- **Yosys 論理合成 DFF カウント結果**:
  - `em_fanout_net`: 65 DFFs (64 sinks + 1 src) — **シンクFFの併合なし確認**
  - `em_rx_bank`: 32 DFFs
  - `em_tx_bank`: 32 DFFs
  - `em_stress` トップ (MISR 32bit + MMIO 36bit): 68 DFFs
  - **総DFF数**: **197** ($\ge 129$ を大幅に満足)
