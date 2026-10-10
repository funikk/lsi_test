# 商用40nm PDK セル差し替え・マッピング仕様書 (cell_map.md)

本ドキュメントは、VDRV_v3 を商用40nm PDK（TSMC 40nm / GLOBALFOUNDRIES 40nm / UMC 40nm 等）環境でインプリメンテーション（論理合成・配置配線・EM/IRドロップ解析）する際に必要な、PDK依存セルのマッピングおよび置換方針を定義します。

---

## 1. 共通方針

VDRV_v3 の RTL は特定のファウンドリ・PDK に依存しない高ポータビリティ設計を採用しています。
PDK固有のセル（SRAM、クロックゲーティング、アイソレーション、パワースイッチ）はすべて `common/rtl/` 以下のラッパーモジュールを経由してインスタンス化されています。

商用インプリ時は、以下のいずれかのアプローチを選択します：
- **アプローチ A (ラッパー置換)**: ラッパーモジュールの内部（`common/rtl/*.v`）を、PDK固有のマクロ／プリミティブに差し替える。
- **アプローチ B (ツール自動挿入 / UPF連携)**: 合成・PnRツール（Design Compiler / Innovus / Genus 等）および UPF にセル挿入を委ね、ラッパーセルをブラックボックスまたは透過的に処理する。

---

## 2. PDK依存セル対応表 (40nm想定)

| ラッパーモジュール | RTL振る舞いモデル | 商用40nm 想定ターゲット | 備考 / 接続仕様 |
|:---|:---|:---|:---|
| `vdrv_icg` | ラッチ + AND ゲート (`always @(*) latch, assign gclk = en_lat & clk`) | **標準ライブラリ ICG セル**<br>(例: `CKLNQD*`, `CKG*`) | セットアップ/ホールドタイミングの保証、クロックツリー合成(CTS)でのクロックピン認識 |
| `vdrv_sram_wrap` | Verilog 2次元配列 (`reg [31:0] mem [...]`) 1R1W | **メモリコンパイラ生成 Single-Port SRAM**<br>(例: `TS1N40*SP*` 512x32 / 1024x32) | タイル内SRAM (4KB) および CPU DMEM (4KB)。チップイネーブル、ライトマスク(byte-enable)を対応づけ |
| `vdrv_iso_and` | プリミティブ AND ゲート (`assign q = d & iso_en`) | **ライブラリ Isolation セル**<br>(例: `ISOLAND*`, `ISOLOR*`) | UPF/CPFによる自動挿入時は RTL 側のラッパーをバイパス可能。クランプ値 LOW (0) 固定 |
| *(Top/RTLポート)* `sw_trickle_en`<br>`sw_main_en` | テストベンチモデル `vdrv_pwr_switch_model` | **Header / Footer パワースイッチセル**<br>(例: `HEADER_HD*`, `PSWITCH*`) | Trickle: 高抵抗/小サイズスイッチ (突入電流抑制)<br>Main: 低抵抗/大サイズスイッチ (定常IRドロップ最小化) |

---

## 3. 各ラッパーの差し替え詳細

### 3.1 クロックゲーティングセル (`vdrv_icg.v`)
- **商用セル例 (TSMC 40nm)**: `CKLNQD4BWP40` / `CKLNQD8BWP40` (ネガティブエッジラッチ型)
- **ピン接続マッピング**:
  ```verilog
  // TSMC 40nm ICG インスタンス化の例
  CKLNQD4BWP40 u_icg_cell (
      .CP (clk),
      .E  (en),
      .TE (test_en),  // DFTスキャンテスト時に 1'b0 または scan_enable
      .Q  (gclk)
  );
  ```

### 3.2 SRAMマクロ (`vdrv_sram_wrap.v`)
- **仕様**: 32-bit 幅、バイト書き込みイネーブル（4-bit `wstrb`）、1サイクル読み出しレイテンシ。
- **商用セル例 (40nm)**: Memory Compiler 出力 Single-Port Sync SRAM (`TS1N40LP_SP_512X32` 等)
- **ピン接続マッピング**:
  ```verilog
  // 商用 SRAM マクロ インスタンス化の例
  TS1N40LP_SP_1024X32 u_sram_macro (
      .CLK  (clk),
      .CEB  (~valid),             // アクティブ LOW
      .WEB  (~(|wstrb)),          // ライトイネーブル (LOW)
      .BWEB (~{{8{wstrb[3]}}, {8{wstrb[2]}}, {8{wstrb[1]}}, {8{wstrb[0]}}}), // ビット/バイトマスク
      .A    (addr[11:2]),         // ワードアドレス
      .D    (wdata),
      .Q    (rdata)
  );
  ```

### 3.3 パワースイッチ (Header / Footer Switch)
- **物理配置仕様**:
  - 商用インプリでは、各行の Power Domain（PD_ROW0〜PD_ROW{G-1}）のセル列に沿って、リング状またはアレイ状にスイッチセルを分散配置（Daisy Chain接続）。
  - **Trickle スイッチ群**: 最初のイネーブル `sw_trickle_en[g]` で点弧。チェーンの末端出力を `sw_trickle_ack[g]` として Power Manager にフィードバック。
  - **Main スイッチ群**: `sw_trickle_ack[g]` 受信 + タイマ後、`sw_main_en[g]` で主スイッチ群を一斉点弧。末端を `sw_main_ack[g]` としてフィードバック。

---

## 4. EMストレス構造の物理設計ガイドライン

`em_stress` ブロックを実チップまたは詳細DEF上で高精度に解析ツールへ認識させるための指針：

1. **広幅高トグルバス (`EM_BUS_WIDTH=32`)**:
   - `em_tx_bank` (送信側) と `em_rx_bank` (受信側) にフロアプラン上で物理的配置制約（Floorplan Guided Region / Soft Macro Placement）を付与し、ダイの対角（例: 左下と右上）に離して配置する。
   - 配線層を特定の下層メタル（例: M2/M3）に限定し、電流密度を高めることで EM 寿命（Black の式）の厳しいクリティカルネットを生成する。
2. **高ファンアウト網 (`EM_FANOUT=64`)**:
   - ドライバセルに `set_dont_touch` または `set_max_fanout` 例外を設定し、バッファツリーの挿入を禁止。
   - 1本の高駆動ドライバ（例: `BUFFD16BWP40`）から64個のFFクロック/データ端子に直接配線し、配線抵抗・ビア電流集中を評価可能にする。
