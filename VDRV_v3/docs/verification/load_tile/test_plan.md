# load_tile 検証計画・結果

テストベンチ：`blocks/load_tile/tb/tb_load_tile.v`（`make BLOCK=load_tile block_sim`）
構成：標準タイル×2（ID 00, 01）、低活性タイル（ID 02、`LOWACT_FFS`=256）、SRAMタイル（ID 13）が同じ設定バスを共有する。

| No | 項目 | 確認内容 | 結果 |
|:--:|:--|:--|:--:|
| 1 | リセット | `load_active`=0、シグネチャ=0 | OK |
| 2 | 常時ON | 全タイルがアクティブ。同じ構成の標準タイル同士でシグネチャが一致し、0でない。低活性・SRAMタイルにXがない | OK |
| 3 | SIG_CLEAR | 全タイルのシグネチャが0になる | OK |
| 4 | 周期パターン | PERIOD=10、DUTY=3 でデューティ30%。PHASEの差5サイクルがそのまま立ち上がりのずれになる | OK |
| 5 | クロックゲーティング | GATE_MODE=1かつOFFでgclkが停止し、シグネチャが凍結。GATE_MODE=0ならgclkは動き続ける | OK |
| 6 | 活性率 | ACT_LEVEL=0で `d` が静止。ACT_LEVEL=8で、マスクされたビットは変化せず、有効なビットは変化する | OK |
| 7 | ブロードキャスト | 列（0xF1）と行（0x1F）のブロードキャストが、該当するタイルにだけ効く | OK |
| 8 | シード | SEED_MIX_IDでタイル間のシグネチャが分かれる。共通シードを再読み込みすると一致に戻る | OK |
| 9 | ランダムバースト | デューティが約50%（199/400） | OK |

lint：`make lint` で警告なし（SYNCASYNCNETは、再利用したaes_coreが同期リセットのため除外）。presynth_check：問題0件。
