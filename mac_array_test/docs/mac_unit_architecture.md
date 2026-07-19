# MAC Unit Architecture

シストリック・アレイ（MACアレイ）を構成する最小単位のブロックである「MAC (Multiply-Accumulate: 積和演算) ユニット」のアーキテクチャについて説明します。

## 1. MAC演算器の基本動作
MACユニットは、名前の通り **「乗算（Multiply）」** と **「加算（Accumulate）」** を同時に行う回路です。

動作を数式で表すと、以下の計算を1クロックサイクルごとに行います。
`出力 = C + (A × B)`

さらに、シストリック・アレイとして全体を接続するために、計算に用いた入力値 `A` と `B` を、バケツリレーのようにそのまま次のセルへ受け渡す（パススルーする）役割も持っています。具体的には以下の3つの処理がレジスタ（フリップフロップ）を介してクロックに同期して同時に行われます。

1. **演算**: 入力 `a_in` と `b_in` を掛け合わせ、その結果を入力 `c_in`（前段からの部分和）に足し合わせて `mac_out` レジスタに保存する。
2. **データAの伝播**: 入力 `a_in` をそのまま `a_out` レジスタに保存し、横方向の次のセルへ渡す。
3. **データBの伝播**: 入力 `b_in` をそのまま `b_out` レジスタに保存し、縦方向の次のセルへ渡す。

## 2. 回路構成図
MACユニット単体の回路構成を概念図で表すと以下のようになります。青色の四角はクロックに同期してデータを保持するフリップフロップ（レジスタ）です。

```mermaid
flowchart TD
    %% Inputs
    Ain(["a_in (8-bit)"])
    Bin(["b_in (8-bit)"])
    Cin(["c_in (16-bit)"])

    %% Operations
    MULT(("×"))
    ADD("+")

    %% Registers (Flip-Flops)
    REG_A["FF: a_out"]
    REG_B["FF: b_out"]
    REG_MAC["FF: mac_out"]

    %% Logic Connections
    Ain --> MULT
    Bin --> MULT
    MULT -- "A×B" --> ADD
    Cin --> ADD

    %% Flip-Flop Connections
    Ain -->|"Pass through"| REG_A
    Bin -->|"Pass through"| REG_B
    ADD -- "C+(A×B)" --> REG_MAC

    %% Outputs
    REG_A --> Aout(["a_out (8-bit) 行の次セルへ"])
    REG_B --> Bout(["b_out (8-bit) 列の次セルへ"])
    REG_MAC --> MACout(["mac_out (16-bit) 列の次セルへ"])

    %% Styling
    classDef reg fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#000;
    classDef op fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:#000,shape:circle;
    class REG_A,REG_B,REG_MAC reg;
    class MULT,ADD op;
```

## 3. アレイ全体の接続図 (2x2の例)
MACユニットを2行2列で配置し、`mac_array` を構成した際のデータの流れは以下のようになります。
* **データA**: 左辺から入力され、右へ伝播します。
* **データB**: 上辺から入力され、下へ伝播します。
* **データC (部分和)**: 上辺から入力（初期値0）され、計算されながら下へ伝播し、最下部から最終結果が出力されます。

```mermaid
flowchart TD
    %% Inputs
    A0["A_in[0]"]
    A1["A_in[1]"]
    B0["B_in[0]"]
    B1["B_in[1]"]
    C0["C_in[0] (0)"]
    C1["C_in[1] (0)"]

    %% MAC Units
    MAC00["MAC (0,0)"]
    MAC01["MAC (0,1)"]
    MAC10["MAC (1,0)"]
    MAC11["MAC (1,1)"]

    %% Connections for Row 0
    A0 -->|"A"| MAC00
    MAC00 -->|"A"| MAC01
    MAC01 -->|"A_out"| Aout0["A_out[0]"]

    %% Connections for Row 1
    A1 -->|"A"| MAC10
    MAC10 -->|"A"| MAC11
    MAC11 -->|"A_out"| Aout1["A_out[1]"]

    %% Connections for Col 0
    B0 -->|"B"| MAC00
    C0 -->|"C"| MAC00
    MAC00 -->|"B"| MAC10
    MAC00 -->|"C+(A×B)"| MAC10
    MAC10 -->|"B_out"| Bout0["B_out[0]"]
    MAC10 -->|"MAC_out"| Cout0["MAC_out[0]"]

    %% Connections for Col 1
    B1 -->|"B"| MAC01
    C1 -->|"C"| MAC01
    MAC01 -->|"B"| MAC11
    MAC01 -->|"C+(A×B)"| MAC11
    MAC11 -->|"B_out"| Bout1["B_out[1]"]
    MAC11 -->|"MAC_out"| Cout1["MAC_out[1]"]

    %% Layout Hints
    subgraph Row0 ["Row 0"]
        MAC00
        MAC01
    end
    subgraph Row1 ["Row 1"]
        MAC10
        MAC11
    end

    %% Styling
    classDef mac fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#000;
    classDef inout_node fill:#f1f8e9,stroke:#558b2f,stroke-width:2px,color:#000;
    class MAC00,MAC01,MAC10,MAC11 mac;
    class A0,A1,B0,B1,C0,C1,Aout0,Aout1,Bout0,Bout1,Cout0,Cout1 inout_node;
    style Row0 fill:none,stroke:none;
    style Row1 fill:none,stroke:none;
```

## 4. PnRおよびIR-Drop解析における利点
この構成では、すべてのセルの中に「乗算器」「加算器」という**非常にロジック密度の高い組み合わせ回路**と、多数の「フリップフロップ」が存在します。

データが入力されると、アレイ全体のすべてのMACユニットが一斉に乗算と加算の計算を実行するため、チップ全体の電力網（Power Grid）に対して均一かつ非常に大きなダイナミック消費電力を発生させることができます。また、パラメータ（ROWS, COLS）によってアレイサイズを自由に変更できるため、EDAツールの処理能力に応じたストレステスト環境を容易に構築可能です。
