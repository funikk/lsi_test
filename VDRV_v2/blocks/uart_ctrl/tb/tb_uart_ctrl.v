`timescale 1ns/1ps

module tb_uart_ctrl;

    reg clk;
    reg rst_n;
    reg rx;
    wire tx;

    wire cmd_set_step;
    wire cmd_start_seq;
    wire cmd_stop_seq;
    wire [3:0] step_id;
    wire [1:0] step_state;
    wire [15:0] step_duration;

    uart_ctrl u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .tx(tx),
        .cmd_set_step(cmd_set_step),
        .cmd_start_seq(cmd_start_seq),
        .cmd_stop_seq(cmd_stop_seq),
        .step_id(step_id),
        .step_state(step_state),
        .step_duration(step_duration)
    );

    initial clk = 0;
    always #5 clk = ~clk; // 100MHz (10ns period)

    localparam CLK_PER_BIT = 868;
    localparam BIT_PERIOD = CLK_PER_BIT * 10;

    task send_byte;
        input [7:0] data;
        integer i;
        begin
            rx = 1'b0; // start bit
            #(BIT_PERIOD);
            for (i=0; i<8; i=i+1) begin
                rx = data[i];
                #(BIT_PERIOD);
            end
            rx = 1'b1; // stop bit
            #(BIT_PERIOD);
        end
    endtask

    reg set_step_flag = 0;
    reg start_seq_flag = 0;

    always @(posedge clk) begin
        if (cmd_set_step) set_step_flag <= 1;
        if (cmd_start_seq) start_seq_flag <= 1;
    end

    initial begin
        $dumpfile("tb_uart_ctrl.vcd");
        $dumpvars(0, tb_uart_ctrl);

        rst_n = 0;
        rx = 1;
        #100;
        rst_n = 1;
        #100;

        // Send SET_STEP packet: AA 55 01 [State(2b), 0(2b), ID(4b)] Dur_H Dur_L
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'h01);
        send_byte(8'hC5); // state=3, id=5
        send_byte(8'h12);
        send_byte(8'h34);

        #(BIT_PERIOD * 2);

        if (set_step_flag && step_id == 5 && step_state == 3 && step_duration == 16'h1234) begin
            $display("PASS: SET_STEP correctly decoded.");
        end else begin
            $display("FAIL: SET_STEP incorrect.");
        end

        // Send START_SEQ: AA 55 02
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'h02);

        #(BIT_PERIOD * 2);

        if (start_seq_flag) begin
            $display("PASS: START_SEQ correctly decoded.");
        end else begin
            $display("FAIL: START_SEQ incorrect.");
        end

        $finish;
    end

endmodule
