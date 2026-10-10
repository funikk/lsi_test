// vdrv_icg: PDK-independent integrated clock gating wrapper.
// Behavioral model: latch enable while clk_i is low, AND with clk_i.
// In the commercial flow, replace the body with the library ICG cell
// (see impl/commercial/cell_map.md). Keep the port list unchanged.
module vdrv_icg (
    input  wire clk_i,
    input  wire en_i,
    input  wire te_i,
    output wire clk_o
);
    reg en_latched;

    /* verilator lint_off LATCH */
    always @(*) begin
        if (!clk_i)
            en_latched = en_i | te_i;
    end
    /* verilator lint_on LATCH */

    assign clk_o = clk_i & en_latched;
endmodule
