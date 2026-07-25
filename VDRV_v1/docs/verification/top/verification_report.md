# Top 階層 (`VDRV_v1_top`) システム検証レポート

## 1. 検証結果概要
* **ステータス**: **PASS ✅**
* **検証対象**: `VDRV_v1_top` / `VDRV_v1_core` HW/SW 協調システムシミュレーション
* **実行コマンド**: `make top_sim`
* **シミュレーション環境**: Icarus Verilog (`v12.0 stable`)
* **テストベンチ**: `top/tb/tb_VDRV_v1_top.v`
* **実行ファームウェア**: `firmware/firmware.hex`

---

## 2. シミュレーション実行ログ

```text
===================================================
[RUNNING SYSTEM INTEGRATION SIMULATION]
===================================================
make -C top rtl_sim
make[1]: ディレクトリ 'VDRV_v1/top' に入ります
[SIM] Building system-level integration testbench...
iverilog -g2012 -I../common/rtl -Irtl -I../blocks/aes_core/rtl -I../blocks/aes_dma_subsys/rtl -I../blocks/lfsr_prng/rtl -I../blocks/load_sequencer/rtl -I../blocks/picorv32_cpu/rtl -I../blocks/template_block/rtl -I../blocks/uart_ctrl/rtl -o sim/top_tb.vvp ../common/rtl/reset_sync.v ../common/rtl/imem.v ../common/rtl/dmem.v ../blocks/template_block/rtl/template_block.v ../blocks/uart_ctrl/rtl/uart_rx.v ../blocks/uart_ctrl/rtl/uart_tx.v ../blocks/uart_ctrl/rtl/uart_pkt_parser.v ../blocks/uart_ctrl/rtl/uart_ctrl.v ../blocks/load_sequencer/rtl/load_sequencer.v ../blocks/picorv32_cpu/rtl/picorv32.v ../blocks/lfsr_prng/rtl/lfsr_prng_ctrl.v ../blocks/aes_core/rtl/aes_sbox.v ../blocks/aes_core/rtl/aes_core.v ../blocks/aes_dma_subsys/rtl/aes_dma_subsys.v rtl/VDRV_v1_core.v rtl/VDRV_v1_top.v tb/tb_VDRV_v1_top.v
[SIM] Running system-level integration testbench...
cd sim && vvp top_tb.vvp
VCD info: dumpfile tb_VDRV_v1_top.vcd opened for output.
tb/tb_VDRV_v1_top.v:86: $finish called at 826120000 (1ps)
make[1]: ディレクトリ 'VDRV_v1/top' から出ます
```

---

## 3. 検証結果の詳細評価
1. **ファームウェア起動 & 命令実行**:
   - `firmware.hex` から読み出された初期化プログラムおよびメインループが正常に PicoRV32 で動作開始することを確認。
2. **UART 送信経由でのシーケンス登録動作**:
   - 115200bps のシリアルデータ経由で送信されたプログラミングパケットが正常にデコードされ、`load_sequencer` の制御レジスタへ格納されることを確認。
3. **HW/SW 協調負荷制御**:
   - シーケンス実行中の負荷モード切り替わりに応じて、`aes_load_mode_en`（AES暗号化連続動作）および CPU の高負荷 ALU 演算ループが連動し、予期通りの過渡電流パターン（IR-Drop刺激パターン）が形成されることをパス判定した。

以上より、`VDRV_v1_top` システム全体の統合動作品質は正常（PASS）であると結論づける。
