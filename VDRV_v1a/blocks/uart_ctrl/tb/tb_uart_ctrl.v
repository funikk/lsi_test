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
    wire [2:0] step_state;
    wire [15:0] step_duration;

    integer errors = 0;

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

    // Pulse capture registers
    reg set_step_seen;
    reg [3:0] captured_id;
    reg [2:0] captured_state;
    reg [15:0] captured_duration;
    reg start_seq_seen;
    reg stop_seq_seen;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            set_step_seen <= 1'b0;
            captured_id <= 4'd0;
            captured_state <= 3'd0;
            captured_duration <= 16'd0;
            start_seq_seen <= 1'b0;
            stop_seq_seen <= 1'b0;
        end else begin
            if (cmd_set_step) begin
                set_step_seen <= 1'b1;
                captured_id <= step_id;
                captured_state <= step_state;
                captured_duration <= step_duration;
            end
            if (cmd_start_seq) begin
                start_seq_seen <= 1'b1;
            end
            if (cmd_stop_seq) begin
                stop_seq_seen <= 1'b1;
            end
        end
    end

    task test_set_step;
        input [3:0] exp_id;
        input [2:0] exp_state;
        input [15:0] exp_dur;
        begin
            set_step_seen = 0;
            // Send SET_STEP packet: AA 55 01 [res(1b), state(3b), id(4b)] Dur_H Dur_L
            send_byte(8'hAA);
            send_byte(8'h55);
            send_byte(8'h01);
            send_byte({1'b0, exp_state, exp_id});
            send_byte(exp_dur[15:8]);
            send_byte(exp_dur[7:0]);

            #(BIT_PERIOD * 2);

            if (set_step_seen && (captured_id == exp_id) && (captured_state == exp_state) && (captured_duration == exp_dur)) begin
                $display("PASS: SET_STEP id=%0d state=3'b%03b (0x%0x) dur=0x%04x decoded correctly.",
                         exp_id, exp_state, exp_state, exp_dur);
            end else begin
                $display("FAIL: SET_STEP expected id=%0d state=3'b%03b dur=0x%04x, got seen=%b id=%0d state=3'b%03b dur=0x%04x",
                         exp_id, exp_state, exp_dur, set_step_seen, captured_id, captured_state, captured_duration);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_uart_ctrl.vcd");
        $dumpvars(0, tb_uart_ctrl);

        rst_n = 0;
        rx = 1;
        #200;
        rst_n = 1;
        #200;

        $display("--- Test 1: SET_STEP 3-bit state 3'b001 (MAC_ONLY) ---");
        test_set_step(4'd1, 3'b001, 16'h0100);

        $display("--- Test 2: SET_STEP 3-bit state 3'b010 (CRC_ONLY) ---");
        test_set_step(4'd2, 3'b010, 16'h0250);

        $display("--- Test 3: SET_STEP 3-bit state 3'b011 (MAC_CRC) ---");
        test_set_step(4'd3, 3'b011, 16'h03A0);

        $display("--- Test 4: SET_STEP 3-bit state 3'b111 (ALL_FULL) ---");
        test_set_step(4'd7, 3'b111, 16'h1234);

        $display("--- Test 5: CMD_START_SEQ (AA 55 02) ---");
        start_seq_seen = 0;
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'h02);
        #(BIT_PERIOD * 2);
        if (start_seq_seen) begin
            $display("PASS: CMD_START_SEQ decoded successfully.");
        end else begin
            $display("FAIL: CMD_START_SEQ not detected.");
            errors = errors + 1;
        end

        $display("--- Test 6: CMD_STOP_SEQ (AA 55 03) ---");
        stop_seq_seen = 0;
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'h03);
        #(BIT_PERIOD * 2);
        if (stop_seq_seen) begin
            $display("PASS: CMD_STOP_SEQ decoded successfully.");
        end else begin
            $display("FAIL: CMD_STOP_SEQ not detected.");
            errors = errors + 1;
        end

        #(BIT_PERIOD * 5);

        if (errors == 0) begin
            $display("========================================");
            $display("ALL UART_CTRL TESTS PASSED (errors=%0d)", errors);
            $display("========================================");
        end else begin
            $display("========================================");
            $display("UART_CTRL TESTS FAILED with %0d errors", errors);
            $display("========================================");
        end

        $finish;
    end

endmodule
