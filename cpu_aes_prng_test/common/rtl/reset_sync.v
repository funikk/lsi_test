// Reset Synchronizer using direct SkyWater 130nm Standard Cell (sky130_fd_sc_hs__dfrtp)
module reset_sync (
    input  wire clk,
    input  wire ext_rst_n,
    output wire sync_rst_n
);
    wire rff1;

    // First stage D-FF
    sky130_fd_sc_hs__dfrtp u_dff1 (
        .CLK(clk),
        .D(1'b1),
        .RESET_B(ext_rst_n),
        .Q(rff1)
    );

    // Second stage D-FF
    sky130_fd_sc_hs__dfrtp u_dff2 (
        .CLK(clk),
        .D(rff1),
        .RESET_B(ext_rst_n),
        .Q(sync_rst_n)
    );

endmodule

// Fallback behavioural model for RTL simulation tools (iverilog / verilator)
`ifndef SKY130_FD_SC_HS__DFRTP_DEFINED
`define SKY130_FD_SC_HS__DFRTP_DEFINED
(* keep_hierarchy *)
module sky130_fd_sc_hs__dfrtp (
    input  wire CLK,
    input  wire D,
    input  wire RESET_B,
    output reg  Q
);
    always @(posedge CLK or negedge RESET_B) begin
        if (!RESET_B) begin
            Q <= 1'b0;
        end else begin
            Q <= D;
        end
    end
endmodule
`endif
