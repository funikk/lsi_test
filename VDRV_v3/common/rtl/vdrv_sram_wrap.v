// vdrv_sram_wrap: PDK-independent single-port SRAM wrapper.
// Behavioral model with 1-cycle read latency and byte write mask.
// In the commercial flow, replace the body with a memory-compiler macro
// (see impl/commercial/cell_map.md). Keep the port list unchanged.
module vdrv_sram_wrap #(
    parameter AW = 10,
    parameter DW = 32
)(
    input  wire            clk,
    input  wire            ce,
    input  wire            we,
    input  wire [AW-1:0]   addr,
    input  wire [DW-1:0]   wdata,
    input  wire [DW/8-1:0] wmask,
    output reg  [DW-1:0]   rdata
);
    reg [DW-1:0] mem [0:(1<<AW)-1];

    integer b;
    always @(posedge clk) begin
        if (ce) begin
            if (we) begin
                for (b = 0; b < DW/8; b = b + 1) begin
                    if (wmask[b])
                        mem[addr][b*8 +: 8] <= wdata[b*8 +: 8];
                end
            end else begin
                rdata <= mem[addr];
            end
        end
    end
endmodule
