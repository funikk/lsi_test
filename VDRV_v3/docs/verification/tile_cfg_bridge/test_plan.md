# Tile Config Bridge (`tile_cfg_bridge`) テスト計画書および検証結果

## 1. 検証概要
`tile_cfg_bridge` ブロックのMMIOプログラミング機能、設定バスパルス生成、シグネチャ個別・XOR読み出し、パラメータ拡張性（NT=6およびNT=40）に対する検証計画と結果をまとめる。

## 2. 検証項目
1. **静的検証 (Lint)**
   - Verilator (`-Wall`) による静的解析（警告0件）。
   - パラメータ `NT=6` および大規模構成 `NT=40` (`-GNT=40`) でのクリーン性確認。
2. **前合成チェック (Presynth Check)**
   - Yosys による `proc; check -assert` 実行。意図しないラッチ生成や組合せループがないこと。
3. **レジスタアクセスおよびパルス生成検証 (Unit Sim)**
   - `NUM_TILES` レジスタの読み出し値が `NT` と一致すること。
   - `CFG_TARGET` および `CFG_WDATA` 書き込み時、正確に1サイクルだけ `cfg_valid` が立ち上がり、ターゲットID/アドレス/データが設定バスに出力されること。
   - `CTRL` bit[0]への1書き込みで `sw_pg_sync` パルスが1サイクル出力され、リードバックでbit[0]が0になること。
   - `CTRL` bit[5:4]（`sw_profile_id`）の書き込みおよびリードバック。
   - 全タイルシグネチャに対する `SIG_XOR` 集計値の正当性確認。
   - `SIG_SEL` 切り替えによる各タイル `SIG_DATA` の正確な読み出し。

## 3. テストベンチ構成
- テストベンチファイル: `tb/tb_tile_cfg_bridge.v`
- 自己判定機能: 全項目の一致を確認後、`TEST PASSED` を出力して `$finish(0)`。エラー時は `TEST FAILED` を出力して `$finish(1)`。
- ウォッチドッグタイマ: 50µsでタイムアウト。

## 4. 検証結果
- **Verilator Lint**: PASSED (`NT=6` および `-GNT=40` 共に警告0件)
- **Pre-synthesis Check**: PASSED (0 problems reported)
- **単体シミュレーション (unit_sim)**: PASSED (`TEST PASSED`)
