/* verilator lint_off DECLFILENAME */

module lfsr_32_ctrl(
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire load_seed,
    input wire [31:0] seed_in,
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
            out <= seed_in;
        end else if (load_seed) begin
            out <= seed_in;
        end else if (en) begin
            out <= next_lfsr32(out);
        end
    end
endmodule

module lfsr_prng_ctrl(
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire load_seed,
    input wire [127:0] seed_in,
    output wire [127:0] out
);
    lfsr_32_ctrl u_lfsr0 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .load_seed(load_seed),
        .seed_in(seed_in[31:0]),
        .out(out[31:0])
    );

    lfsr_32_ctrl u_lfsr1 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .load_seed(load_seed),
        .seed_in(seed_in[63:32]),
        .out(out[63:32])
    );

    lfsr_32_ctrl u_lfsr2 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .load_seed(load_seed),
        .seed_in(seed_in[95:64]),
        .out(out[95:64])
    );

    lfsr_32_ctrl u_lfsr3 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .load_seed(load_seed),
        .seed_in(seed_in[127:96]),
        .out(out[127:96])
    );
endmodule
