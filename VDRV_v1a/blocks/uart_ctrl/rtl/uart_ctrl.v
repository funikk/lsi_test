module uart_ctrl (
    input wire clk,
    input wire rst_n,

    input wire rx,
    output wire tx,

    output wire cmd_set_step,
    output wire cmd_start_seq,
    output wire cmd_stop_seq,

    output wire [3:0] step_id,
    output wire [2:0] step_state,
    output wire [15:0] step_duration
);

    wire [7:0] rx_data;
    wire rx_valid;

    uart_rx #(
        .CLK_PER_BIT(868)
    ) u_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    /* verilator lint_off UNUSEDSIGNAL */
    wire tx_active_dummy;
    /* verilator lint_on UNUSEDSIGNAL */

    uart_tx #(
        .CLK_PER_BIT(868)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(1'b0),
        .tx_data(8'h00),
        .tx_active(tx_active_dummy),
        .tx(tx)
    );

    uart_pkt_parser u_parser (
        .clk(clk),
        .rst_n(rst_n),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .cmd_set_step(cmd_set_step),
        .cmd_start_seq(cmd_start_seq),
        .cmd_stop_seq(cmd_stop_seq),
        .step_id(step_id),
        .step_state(step_state),
        .step_duration(step_duration)
    );

endmodule
