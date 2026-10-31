`default_nettype none

module crc_channel #(
    parameter UNROLL_STEPS = 48
)(
    input  wire [31:0] data_in,
    input  wire [31:0] poly_in,
    input  wire [31:0] coeff_in,
    output wire [31:0] data_out
);
    wire [31:0] poly_mask = poly_in | 32'h04C11DB7;

    function [31:0] crc_unroll;
        input [31:0] din;
        input [31:0] pmask;
        input [31:0] cin;
        reg [31:0] st;
        reg fb;
        reg [31:0] pterm;
        integer step;
        begin
            st = din;
            for (step = 0; step < UNROLL_STEPS; step = step + 1) begin
                fb = st[31] ^ cin[step % 32];
                pterm = fb ? pmask : 32'h00000000;
                st = {st[30:0], 1'b0} ^ pterm;
            end
            crc_unroll = st;
        end
    endfunction

    assign data_out = crc_unroll(data_in, poly_mask, coeff_in);

endmodule
`default_nettype wire
