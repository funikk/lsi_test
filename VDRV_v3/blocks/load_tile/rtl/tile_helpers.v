// tile_misr_fold: shared helpers are implemented as small modules so that
// each tile core can reuse them without SystemVerilog packages.

// 32-bit MISR. Updates when en=1; sig_clear has priority.
module tile_misr (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire        clr,
    input  wire [31:0] din,
    output reg  [31:0] sig
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sig <= 32'h0;
        else if (clr)
            sig <= 32'h0;
        else if (en)
            sig <= {sig[30:0], sig[31] ^ sig[21] ^ sig[1] ^ sig[0]} ^ din;
    end
endmodule

// Sigma-delta throttle: emits 'go' on average ACT_LEVEL/16 of enabled cycles.
module tile_act_throttle (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    input  wire [4:0] act_level,
    output reg        go
);
    reg  [4:0] acc;
    wire [5:0] sum = {1'b0, acc} + {1'b0, act_level};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= 5'd0;
            go  <= 1'b0;
        end else if (en) begin
            if (sum >= 6'd16) begin
                acc <= sum[4:0] - 5'd16;
                go  <= 1'b1;
            end else begin
                acc <= sum[4:0];
                go  <= 1'b0;
            end
        end else begin
            go <= 1'b0;
        end
    end
endmodule
