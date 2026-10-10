// tile_core_lowact: Low-activity (clock-dominated) load core.
// A long shift register of LOWACT_FFS flops. The serial input is an LFSR bit
// gated so that it toggles only on ~ACT_LEVEL/16 of cycles; with ACT_LEVEL=0
// the data is static and only the clock network consumes power.
module tile_core_lowact #(
    parameter LOWACT_FFS = 4096
)(
    input  wire         gclk,
    input  wire         rst_n,
    input  wire         en,
    input  wire [4:0]   act_level,
    input  wire         seed_load,
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [127:0] seed128,
    /* verilator lint_on UNUSEDSIGNAL */
    input  wire         sig_clear,
    output wire [31:0]  sig
);
    /* verilator lint_off UNUSEDSIGNAL */
    wire [31:0] rnd;
    /* verilator lint_on UNUSEDSIGNAL */
    lfsr_32_ctrl u_lfsr (
        .clk       (gclk),
        .rst_n     (rst_n),
        .en        (en),
        .load_seed (seed_load),
        .seed_in   (seed128[31:0]),
        .out       (rnd)
    );

    wire sin = rnd[31] & ({1'b0, rnd[3:0]} < act_level);

    reg [LOWACT_FFS-1:0] sr;
    always @(posedge gclk or negedge rst_n) begin
        if (!rst_n)
            sr <= {LOWACT_FFS{1'b0}};
        else if (en)
            sr <= {sr[LOWACT_FFS-2:0], sin};
    end

    tile_misr u_misr (
        .clk(gclk), .rst_n(rst_n), .en(en), .clr(sig_clear),
        .din(sr[LOWACT_FFS-1 -: 32]), .sig(sig)
    );
endmodule
