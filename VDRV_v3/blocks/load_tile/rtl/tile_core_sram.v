// tile_core_sram: SRAM load core. SRAM_BANKS instances of vdrv_sram_wrap run a
// continuous write-then-read sweep (write addr N, read addr N, N+1, ...).
// Accesses are throttled to ~ACT_LEVEL/16 of enabled cycles.
module tile_core_sram #(
    parameter SRAM_AW    = 6,
    parameter SRAM_BANKS = 2
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
    wire [31:0] rnd;
    lfsr_32_ctrl u_lfsr (
        .clk       (gclk),
        .rst_n     (rst_n),
        .en        (en),
        .load_seed (seed_load),
        .seed_in   (seed128[63:32]),
        .out       (rnd)
    );

    wire go;
    tile_act_throttle u_thr (
        .clk(gclk), .rst_n(rst_n), .en(en), .act_level(act_level), .go(go)
    );

    reg               phase_rd;   // 0: write, 1: read
    reg [SRAM_AW-1:0] addr;
    reg               rd_valid;   // rdata valid this cycle (read issued last cycle)
    wire              access = en && go;

    always @(posedge gclk or negedge rst_n) begin
        if (!rst_n) begin
            phase_rd <= 1'b0;
            addr     <= {SRAM_AW{1'b0}};
            rd_valid <= 1'b0;
        end else begin
            rd_valid <= access && phase_rd;
            if (access) begin
                phase_rd <= ~phase_rd;
                if (phase_rd)
                    addr <= addr + 1'b1;
            end
        end
    end

    wire [32*SRAM_BANKS-1:0] rdata;
    genvar b;
    generate
        for (b = 0; b < SRAM_BANKS; b = b + 1) begin : g_bank
            localparam [31:0] BANK_XOR = 32'h5A5A_0000 + b;
            vdrv_sram_wrap #(.AW(SRAM_AW), .DW(32)) u_sram (
                .clk   (gclk),
                .ce    (access),
                .we    (~phase_rd),
                .addr  (addr),
                .wdata (rnd ^ BANK_XOR),
                .wmask (4'hF),
                .rdata (rdata[b*32 +: 32])
            );
        end
    endgenerate

    reg [31:0] rfold;
    integer i;
    always @(*) begin
        rfold = 32'h0;
        for (i = 0; i < SRAM_BANKS; i = i + 1)
            rfold = rfold ^ rdata[i*32 +: 32];
    end

    tile_misr u_misr (
        .clk(gclk), .rst_n(rst_n), .en(rd_valid), .clr(sig_clear),
        .din(rfold), .sig(sig)
    );
endmodule
