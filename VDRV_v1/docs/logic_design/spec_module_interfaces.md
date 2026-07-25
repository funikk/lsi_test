# モジュール間インターフェース標準仕様書 (Module Interface Specification)

**担当専門家**: Logic Design Engineer (`logic_design`)  

---

## 1. モジュール結合インターフェース規約
- 全てのサブブロックは単一のポジティブエッジクロック (`clk`) およびアクティブローリセット (`rst_n`) に同期して動作すること。
- モジュール間のデータ転送は `valid` / `done` パルスハンドシェイクを適用すること。

## 2. パラメータ共有
共通パラメータ (`defines.vh`) は `common/rtl/defines.vh` をインクルードして使用すること。
