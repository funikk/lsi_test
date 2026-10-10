// tile_core_std: Standard high-toggle load core (AES-128 + 128-bit LFSR + MAC array).
// Runs on the gated clock. ACT_LEVEL (0..16) controls:
//   - the fraction of data-register bits refreshed from the LFSR each cycle
//     (bit i refreshes when (i % 16) < ACT_LEVEL), which sets the MAC input
//     toggle rate, and
//   - the AES start rate (sigma-delta throttle, ACT_LEVEL/16 of cycles).
module tile_core_std #(
    parameter MAC_ROWS = 4,
    parameter MAC_COLS = 4
)(
    input  wire         gclk,
    input  wire         rst_n,
    input  wire         en,
    input  wire [4:0]   act_level,
    input  wire         seed_load,
    input  wire [127:0] seed128,
    input  wire         sig_clear,
    output wire [31:0]  sig
);
    localparam AW = MAC_ROWS * 8;
    localparam BW = MAC_COLS * 8;
    localparam CW = MAC_COLS * 16;

    // ---------------- LFSR ----------------
    wire [127:0] rnd;
    lfsr_prng_ctrl u_lfsr (
        .clk       (gclk),
        .rst_n     (rst_n),
        .en        (en),
        .load_seed (seed_load),
        .seed_in   (seed128),
        .out       (rnd)
    );

    // ---------------- Activity-masked data register ----------------
    reg  [127:0] act_mask;
    integer m;
    always @(*) begin
        for (m = 0; m < 128; m = m + 1)
            act_mask[m] = ((m % 16) < act_level);
    end

    reg [127:0] d;
    always @(posedge gclk or negedge rst_n) begin
        if (!rst_n)
            d <= 128'h0;
        else if (en)
            d <= (d & ~act_mask) | (rnd & act_mask);
    end

    // ---------------- AES ----------------
    wire aes_go;
    tile_act_throttle u_thr (
        .clk(gclk), .rst_n(rst_n), .en(en), .act_level(act_level), .go(aes_go)
    );

    reg aes_pending;
    wire aes_busy;
    wire aes_ready;
    wire [127:0] aes_out;
    wire aes_start = en && aes_pending && !aes_busy;

    always @(posedge gclk or negedge rst_n) begin
        if (!rst_n)
            aes_pending <= 1'b0;
        else if (aes_start)
            aes_pending <= aes_go;
        else if (aes_go)
            aes_pending <= 1'b1;
    end

    aes_core u_aes (
        .clk       (gclk),
        .rst_n     (rst_n),
        .start     (aes_start),
        .state_in  (d),
        .key_in    ({d[63:0], d[127:64]}),
        .state_out (aes_out),
        .ready     (aes_ready),
        .busy      (aes_busy)
    );

    // ---------------- MAC array ----------------
    wire [AW-1:0] mac_a;
    wire [BW-1:0] mac_b;
    wire [CW-1:0] mac_c;
    genvar k;
    generate
        for (k = 0; k < AW; k = k + 1) begin : g_a
            assign mac_a[k] = d[k % 128];
        end
        for (k = 0; k < BW; k = k + 1) begin : g_b
            assign mac_b[k] = d[(k + 37) % 128];
        end
        for (k = 0; k < CW; k = k + 1) begin : g_c
            assign mac_c[k] = d[(k + 71) % 128];
        end
    endgenerate

    /* verilator lint_off UNUSEDSIGNAL */
    wire [AW-1:0] mac_a_out;
    wire [BW-1:0] mac_b_out;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [CW-1:0] mac_out;

    mac_array #(
        .ROWS(MAC_ROWS), .COLS(MAC_COLS), .DATA_WIDTH(8), .ACC_WIDTH(16)
    ) u_mac (
        .clk     (gclk),
        .rst_n   (rst_n),
        .en      (en),
        .a_in    (mac_a),
        .b_in    (mac_b),
        .c_in    (mac_c),
        .a_out   (mac_a_out),
        .b_out   (mac_b_out),
        .mac_out (mac_out)
    );

    // ---------------- Signature ----------------
    reg [31:0] mac_fold;
    integer f;
    always @(*) begin
        mac_fold = 32'h0;
        for (f = 0; f < CW; f = f + 1)
            mac_fold[f % 32] = mac_fold[f % 32] ^ mac_out[f];
    end

    wire [31:0] aes_fold = aes_out[31:0] ^ aes_out[63:32] ^ aes_out[95:64] ^ aes_out[127:96];
    wire [31:0] din = aes_fold ^ mac_fold ^ {31'h0, aes_ready};

    tile_misr u_misr (
        .clk(gclk), .rst_n(rst_n), .en(en), .clr(sig_clear), .din(din), .sig(sig)
    );
endmodule
