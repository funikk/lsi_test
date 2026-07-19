# オープンソースEDA環境 構築手順書

本手順書は、Ubuntu環境にオープンソースのEDAツール（シミュレータ、Linter、論理合成ツール等）を導入し、将来的な **Fusion Compiler** 等を用いたPnR（物理設計）学習へ繋げるためのテスト環境を構築する手順です。

---

## 1. 導入するツールとその役割

PnR（物理設計）を学ぶ前段として、回路記述が**合成可能（Synthesizable）**であり、論理的に正しく動作することを検証する環境を整えます。

| ツール名 | 役割 | PnR（Fusion Compiler）との関連性 |
| :--- | :--- | :--- |
| **Verilator** | 高速シミュレータ & 静的解析（Linter） | RTLコードの構文チェックや、合成不可能な記述の検出（商用Linterツールに類似）。 |
| **Icarus Verilog** | IEEE準拠シミュレータ | テストベンチを用いた機能検証（シミュレーション）。 |
| **GTKWave** | 波形ビューア | シミュレーション結果のVCD波形ファイルを表示。 |
| **Yosys** | 論理合成（Logic Synthesis） | RTLからゲートレベル・ネットリストへの変換（Design CompilerやFusion Compilerの合成フェーズに相当）。 |

---

## 2. インストール手順

Ubuntu (Debian系) のパッケージマネージャを用いて、必要なツールをインストールします。

### ステップ 1: パッケージリストの更新
```bash
sudo apt update
```

### ステップ 2: EDAツールのインストール
```bash
sudo apt install -y verilator iverilog gtkwave yosys
```

### ステップ 3: インストールの確認
各ツールのバージョンが表示され、正しくパスが通っていることを確認します。
```bash
verilator --version
iverilog -V
yosys -V
```

---

## 3. エディタ環境の構築 (VS Code推奨)

Verilogのコーディングやデバッグを効率化するために、VS Code（Visual Studio Code）に以下の拡張機能を導入することを推奨します。

1.  **Verilog-HDL/SystemVerilog/Tcl** (by Msys)
    *   構文ハイライト、コード補完、定義ジャンプを提供します。
    *   **設定推奨**: VS Codeの設定で `Verilog > Linting: Linter` を `verilator` に設定すると、ファイル保存時に自動的に Verilator による構文チェックが走り、コード上に波線でエラーや警告が表示されます。
2.  **Tcl Language Support** (または同様のTcl用拡張)
    *   Fusion Compilerなどの商用EDAツールや、Yosysのスクリプトは基本的に **Tcl (Tool Command Language)** で記述します。Tclの文法ハイライトを有効にしておくと便利です。

---

## 4. 環境検証用のクイックスタート

インストール完了後、以下の手順でツールが正常に動作するかテスト回路を用いて検証します。

### ① テスト回路 (counter.v) の作成
レジスタ転送レベル (RTL) の回路です。

```verilog
// counter.v
module counter (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    output reg  [7:0] count
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 8'h00;
        end else if (en) begin
            count <= count + 8'h01;
        end
    end
endmodule
```

### ② テストベンチ (tb_counter.v) の作成
シミュレーションを実行し、波形を出力するためのコードです。

```verilog
// tb_counter.v
`timescale 1ns/1ps

module tb_counter;
    reg clk;
    reg rst_n;
    reg en;
    wire [7:0] count;

    // テスト対象モジュール (DUT) のインスタンス化
    counter u_counter (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .count(count)
    );

    // クロック生成 (50MHz: 周期20ns)
    always #10 clk = ~clk;

    initial begin
        // 波形出力の設定 (GTKWave用)
        $dumpfile("tb_counter.vcd");
        $dumpvars(0, tb_counter);

        // 初期化
        clk = 0;
        rst_n = 0;
        en = 0;

        // リセット解除
        #40;
        rst_n = 1;
        
        // カウント動作開始
        #20;
        en = 1;

        // しばらく待って終了
        #300;
        $finish;
    end
endmodule
```

### ③ 動作検証コマンド

#### 1. Linterの実行 (Verilator)
シンタックスエラーや合成不可の記述がないか静的にチェックします。
```bash
verilator --lint-only -Wall counter.v
```

#### 2. シミュレーションの実行 (Icarus Verilog)
コンパイルして波形データ（VCDファイル）を出力します。
```bash
iverilog -o sim.out tb_counter.v counter.v
vvp sim.out
```

#### 3. 波形の確認 (GTKWave)
出力された `tb_counter.vcd` を読み込んで波形を観察します。
```bash
gtkwave tb_counter.vcd &
```

---

## 5. PnR（物理設計）学習ロードマップ

オープンソース環境で基礎を学んだ後、Fusion Compiler等の商用フローへスムーズに移行するための接続ポイントです。

1.  **論理合成の理解 (Yosys)**
    *   Yosysを使って、記述した `counter.v` を論理合成してみましょう。
    *   `yosys` 起動後、`read_verilog counter.v; synth; write_verilog synth_counter.v` を実行することで、RTLがどのように基本ゲート（AND, OR, Flip-Flop等）にマッピングされるかをテキストで確認できます。
2.  **SDC（Synopsys Design Constraints）の基礎**
    *   PnRにおいて最も重要なのが「タイミング制約」です。クロックの周波数や入力/出力遅延を定義する **SDCファイル** の書き方を学習します。
3.  **Tcl スクリプトによる自動化**
    *   Fusion Compilerなどのツールは、ほぼすべての操作を Tcl スクリプトで記述してバッチ実行します。合成やPnRの各工程をスクリプトで自動実行するスキルを磨いておくことが、商用ツールを扱う際の最大の強みになります。
