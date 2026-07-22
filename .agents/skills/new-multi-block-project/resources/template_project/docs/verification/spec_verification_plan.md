# 検証計画書 (Verification Plan)

**担当専門家**: Logic Verification Engineer (`logic_verification`)  

---

## 1. 検証フェーズ
- 静的コード解析: `make lint`
- 単体シミュレーション: `make -j unit_sim`
- 前処理論理合成チェック: `make presynth_check`
- 統合シミュレーション: `make top_sim`
