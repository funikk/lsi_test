/* verilator lint_off DECLFILENAME */

module lfsr_32(
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire [31:0] seed,
    output reg [31:0] out
);
    function [31:0] next_lfsr32;
        input [31:0] val;
        integer i;
        begin
            next_lfsr32 = val;
            for (i = 0; i < 32; i = i + 1) begin
                next_lfsr32 = {next_lfsr32[30:0], next_lfsr32[31] ^ next_lfsr32[21] ^ next_lfsr32[1] ^ next_lfsr32[0]};
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out <= seed;
        end else if (en) begin
            out <= next_lfsr32(out);
        end
    end
endmodule

module lfsr_prng(
    input wire clk,
    input wire rst_n,
    input wire en,
    output wire [127:0] out
);
    lfsr_32 u_lfsr0 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .seed(32'hA5A5A5A5),
        .out(out[31:0])
    );

    lfsr_32 u_lfsr1 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .seed(32'h5A5A5A5A),
        .out(out[63:32])
    );

    lfsr_32 u_lfsr2 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .seed(32'h01234567),
        .out(out[95:64])
    );

    lfsr_32 u_lfsr3 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .seed(32'h89ABCDEF),
        .out(out[127:96])
    );
endmodule
