# UART Control Block 検証レポート

## 検証結果概要
*   **ステータス**: PASS
*   **シミュレーション環境**: Icarus Verilog
*   **実行対象ファイル**: `tb_uart_ctrl.v`

## テスト実行結果

シミュレーションコマンド `make BLOCK=uart_ctrl block_sim` を実行し、以下の結果を得た。

```
[TARGETED BLOCK SIM] Block: uart_ctrl
make -C blocks/uart_ctrl unit_sim
    make[1]: ディレクトリ 'VDRV_v2/blocks/uart_ctrl' に入ります
iverilog -o sim.vvp -f filelist.f ./tb/tb_uart_ctrl.v
vvp sim.vvp
VCD info: dumpfile tb_uart_ctrl.vcd opened for output.
PASS: SET_STEP correctly decoded.
PASS: START_SEQ correctly decoded.
./tb/tb_uart_ctrl.v:98: $finish called at 816120000 (1ps)
```

## 結果の詳細
1.  **SET_STEPコマンドのデコード**:
    UART経由で送信された SET_STEPパケット (`0xAA 0x55 0x01` ＋ ペイロード) を正しく受信し、`cmd_set_step` 信号および関連パラメータ（`step_id=5`, `step_state=3`, `step_duration=16'h1234`）が想定通りに出力されることを確認した。
2.  **START_SEQコマンドのデコード**:
    UART経由で送信された START_SEQパケット (`0xAA 0x55 0x02`) を正しく受信し、`cmd_start_seq` 信号がアサートされることを確認した。

以上より、`uart_ctrl` モジュールのパケット受信およびコマンドデコード機能が正常に動作していると判断する。
