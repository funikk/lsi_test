# リモートホスト (NFS + SSH) での PnR オフロード実行ガイド

本プロジェクトでは、PnR (LibreLane/OpenROAD) の重い計算処理を、NFS経由でワークスペースを共有した強力な外部ホストへ SSH でオフロード実行する仕組みをサポートしています。

---

## 1. 概要とアーキテクチャ

* **ワークスペース共有 (NFS)**: ローカルホストとリモートホストでプロジェクトディレクトリが NFS マウントされている前提です。ソースコードや PnR 設定 (`config.json`)、生成された成果物 (`runs/`) はリアルタイムに共有されます。
* **SSH 透過オフロード**: `run_pnr.py` スクリプトの `--remote` オプション、または `make pnr PNR_REMOTE=<host>` を指定することで、ローカルからリモートホスト上の Nix Shell (`nix develop ./librelane --command ...`) を呼び出します。

---

## 2. 事前準備 (SSH パスワードなし認証)

リモート実行を自動化するため、ローカルホストからリモートホストへパスワードなしで SSH 接続できるように設定します。

### (1) SSH 公開鍵の転送
ローカルマシンで公開鍵を作成し、リモートホストへ登録します：
```bash
# 鍵ペアが未作成の場合
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519

# リモートホストへ公開鍵を転送
ssh-copy-id user@remote-build-host
```

### (2) SSH Config エイリアスの設定 (推奨)
`~/.ssh/config` にホスト設定を記述しておくと便利です：
```text
Host heavy-pnr
    HostName 192.168.1.100
    User <username>
    IdentityFile ~/.ssh/id_ed25519
```

確認用コマンド：
```bash
ssh heavy-pnr "date"
```
（パスワード入力なしで現在時刻が返ってくれば準備完了です）

---

## 3. PnR 実行方法

### A. Makefile から実行する場合 (おすすめ)

対象サブプロジェクトのディレクトリで、`PNR_REMOTE` 変数を指定します：

```bash
cd counter_test

# リモートホスト指定で実行
make pnr PNR_REMOTE=heavy-pnr

# または環境変数で常時有効化
export PNR_REMOTE_HOST=heavy-pnr
make pnr
```

### B. `run_pnr.py` スクリプトから直接実行する場合

```bash
# プロジェクトルートから
python3 tools/run_pnr.py counter --remote heavy-pnr

# クロック周波数スイープをリモートで実行
python3 tools/run_pnr.py counter --sweep-clk 10.0,8.0,6.67 --remote heavy-pnr
```

---

## 4. AI Agent (Antigravity) での実行とサンドボックス注意点

AI Agent に PnR のリモート実行を依頼する場合、以下のセキュリティ制約にご注意ください：

> [!WARNING]
> **サンドボックス環境でのネットワーク通信制限**
> - AI Agent の標準実行環境 (**Standard Sandbox Mode**) では、外部ネットワーク通信 (SSH ポート 22 への接続) がブロックされます。
> - Agent が `make pnr PNR_REMOTE=...` を実行する際は、Agent が **`BypassSandbox: true`**（サンドボックス回避モード）をユーザーに提案します。
> - 画面に表示される承認プロンプトで「Proceed / 承認」を選択することで、Agent からリモートホストへの SSH 接続が許可され、正常にオフロードが完了します。

---

## 5. トラブルシューティング

| 症状 / エラー | 原因と対処法 |
| :--- | :--- |
| `Permission denied (publickey)` | SSH 鍵が登録されていません。`ssh-copy-id <host>` を実行してください。 |
| `ssh: connect to host ... connection refused` または タイムアウト | リモートホストの IP/ホスト名が正しくないか、Agent が Standard Sandbox モードで制限されています（BypassSandbox を承認してください）。 |
| `Directory not found` / `NFS error` | ローカルとリモートで NFS マウントパスが異なっている可能性があります。マウントパスを統一するか、相対パスアクセスを確認してください。 |
