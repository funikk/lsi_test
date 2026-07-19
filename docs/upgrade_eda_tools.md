# EDAツールの最新バージョン導入手順

Ubuntuの公式パッケージ（apt）で提供されるEDAツールは安定版ですが、最新の言語規格への追従やバグ修正が含まれていないことがあります。より新しいバージョンを導入するための方法（ソースコードからのビルド、および推奨されるプリコンパイル済みスイートの利用）をまとめました。

---

## 1. YosysHQ「OSS CAD Suite」の利用 (最も推奨)

Yosys、nextpnr、およびその他の多くのオープンソースEDAツール（Icarus Verilog等も含む）の最新ビルドを一つにまとめた、プリコンパイル済みのディストリビューションです。ビルドの手間なく、常に最新の開発版を利用できます。

### 導入手順
1.  **アーカイブのダウンロード**:
    [YosysHQ/oss-cad-suite-builds](https://github.com/YosysHQ/oss-cad-suite-builds/releases) から最新の Linux x64 用アーカイブ（`oss-cad-suite-linux-x64-YYYYMMDD.tgz`）をダウンロードします。

2.  **展開と配置**:
    `/opt` ディレクトリなどに展開します。
    ```bash
    sudo tar -xzf oss-cad-suite-linux-x64-*.tgz -C /opt
    ```

3.  **環境変数の設定**:
    `~/.bashrc` または `~/.zshrc` に以下のパスを追加します。
    ```bash
    export PATH="/opt/oss-cad-suite/bin:$PATH"
    ```
    設定を反映します。
    ```bash
    source ~/.bashrc
    ```

*※ これだけで、Yosys, iverilog, gtkwave などが最新のバージョンで一括して利用可能になります。*

---

## 2. Verilator のソースビルド手順

Verilatorは頻繁にアップデートされるため、最新機能を追う場合はソースコードからのビルドが推奨されます。

### ① 必要パッケージのインストール
```bash
sudo apt update
sudo apt install -y git autoconf g++ flex bison make \
                    libfl-dev libgoogle-perftools-dev numactl perl-doc zlib1g-dev
```

### ② ソースの取得とビルド
1.  **リポジトリのクローン**:
    ```bash
    git clone https://github.com/verilator/verilator.git
    cd verilator
    ```
2.  **バージョンの選択** (特定の安定版タグをチェックアウトする場合。最新の master でも可):
    ```bash
    # 例: v5.032 などを指定
    git checkout v5.032
    ```
3.  **ビルド設定と実行**:
    ```bash
    autoconf
    ./configure
    make -j$(nproc)
    ```
4.  **インストール**:
    ```bash
    sudo make install
    ```

---

## 3. Icarus Verilog (iverilog) のソースビルド手順

### ① 必要パッケージのインストール
```bash
sudo apt update
sudo apt install -y git autoconf gperf g++ make bison flex
```

### ② ソースの取得とビルド
1.  **リポジトリのクローン**:
    ```bash
    git clone https://github.com/steveicarus/iverilog.git
    cd iverilog
    ```
2.  **ビルド設定と実行**:
    ```bash
    sh autoconf.sh
    ./configure
    make -j$(nproc)
    ```
3.  **インストール**:
    ```bash
    sudo make install
    ```

---

## 4. Yosys 単体のソースビルド手順

（※ OSS CAD Suiteを使用しない場合）

### ① 必要パッケージのインストール
```bash
sudo apt update
sudo apt install -y git bison flex readline-common libreadline-dev \
                    tcl-dev libffi-dev graphviz xdot pkg-config \
                    python3 libboost-system-dev libboost-python-dev \
                    libboost-filesystem-dev zlib1g-dev g++ make
```

### ② ソースの取得とビルド
1.  **リポジトリのクローン**:
    ```bash
    git clone https://github.com/YosysHQ/yosys.git
    cd yosys
    ```
2.  **ビルドとインストール**:
    ```bash
    # 複数スレッドでビルド
    make -j$(nproc)
    sudo make install
    ```
