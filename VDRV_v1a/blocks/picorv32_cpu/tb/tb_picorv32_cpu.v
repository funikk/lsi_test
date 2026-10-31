`timescale 1ns/1ps
`include "defines.vh"

module tb_picorv32_cpu;

    reg clk;
    reg rst_n;
    reg in_valid;
    reg [`DATA_WIDTH-1:0] in_data;
    wire out_valid;
    wire [`DATA_WIDTH-1:0] out_data;

    picorv32_cpu dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(out_valid),
        .out_data(out_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        in_valid = 0;
        in_data = 0;

        #20;
        rst_n = 1;

        #10;
        in_valid = 1;
        in_data = 128'h1234_5678_9abc_def0_1234_5678_9abc_def0;

        #10;
        in_valid = 0;

        #20;
        if (out_data == 128'h1234_5678_9abc_def0_1234_5678_9abc_def0) begin
            $display("[PASS] picorv32_cpu unit test passed successfully.");
        end else begin
            $display("[FAIL] picorv32_cpu unit test failed.");
            $finish(1);
        end

        $finish(0);
    end

endmodule
