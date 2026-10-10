`include "defines.vh"

module VDRV_v3_top (
    input  wire clk,
    input  wire rst_n,
    input  wire in_valid,
    input  wire [`DATA_WIDTH-1:0] in_data,
    output wire out_valid,
    output wire [`DATA_WIDTH-1:0] out_data
);

    template_block u_template (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(out_valid),
        .out_data(out_data)
    );

endmodule
