`timescale 1ns/1ps
`include "defines.vh"

module tb_VDRV_v2_top;

    reg clk;
    reg rst_n;

    reg in_valid;
    reg [`DATA_WIDTH-1:0] in_data;
    wire out_valid;
    wire [`DATA_WIDTH-1:0] out_data;

    reg uart_rx;
    wire uart_tx;
    wire aes_load_mode_en;
    wire [1:0] cpu_load_state;

    VDRV_v2_top u_top (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(out_valid),
        .out_data(out_data),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .aes_load_mode_en(aes_load_mode_en),
        .cpu_load_state(cpu_load_state)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    localparam CLK_PER_BIT = 868;
    localparam BIT_PERIOD = CLK_PER_BIT * 10;

    task send_byte;
        input [7:0] data;
        integer i;
        begin
            uart_rx = 1'b0; // start bit
            #(BIT_PERIOD);
            for (i=0; i<8; i=i+1) begin
                uart_rx = data[i];
                #(BIT_PERIOD);
            end
            uart_rx = 1'b1; // stop bit
            #(BIT_PERIOD);
        end
    endtask

    initial begin
        $dumpfile("tb_VDRV_v2_top.vcd");
        $dumpvars(0, tb_VDRV_v2_top);

        rst_n = 0;
        in_valid = 0;
        in_data = 0;
        uart_rx = 1;

        #100;
        rst_n = 1;
        #100;

        // Send SET_STEP packet: AA 55 01 [State(2b), 0(2b), ID(4b)] Dur_H Dur_L
        // Step 0: AES_FULL (01), Dur=10 (0x0A) -> data=0100_0000 (0x40)
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'h01);
        send_byte(8'h40);
        send_byte(8'h00);
        send_byte(8'h0A);

        #(BIT_PERIOD * 2);

        // Send START_SEQ: AA 55 02
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'h02);

        // HW-Direct mode must request PD_AES power-on before enabling load.
        #1000;
        if (u_top.u_core.aes_power_ready !== 1'b1) begin
            $fatal(1, "AES_FULL sequence did not power on PD_AES");
        end

        // Stopping the sequence releases the HW request and returns PD_AES
        // to OFF after quiesce/isolation.
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'h03);
        #1000;
        if (u_top.u_core.pd_aes_on !== 1'b0 || u_top.u_core.aes_isolate !== 1'b1) begin
            $fatal(1, "Stopped sequence did not power off and isolate PD_AES");
        end

        // Wait for some sequence to run
        #1000;
        $finish;
    end
endmodule
