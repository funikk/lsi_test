module aes_prng_pd (
    input  wire         clk,
    input  wire         pd_rst_n,
    input  wire         pd_aes_on,
    input  wire         start,
    input  wire [127:0] state_in,
    input  wire [127:0] key_in,
    input  wire         prng_en,
    input  wire         load_seed,
    input  wire [127:0] seed_in,
    output wire [127:0] aes_state_out_raw,
    output wire         aes_ready_raw,
    output wire         aes_busy_raw,
    output wire [127:0] prng_data_raw
);
    wire [127:0] aes_state_out_int;
    wire aes_ready_int;
    wire aes_busy_int;
    wire [127:0] prng_data_int;

    aes_core u_aes (
        .clk(clk), .rst_n(pd_rst_n), .start(start), .state_in(state_in),
        .key_in(key_in), .state_out(aes_state_out_int), .ready(aes_ready_int),
        .busy(aes_busy_int)
    );
    lfsr_prng_ctrl u_prng (
        .clk(clk), .rst_n(pd_rst_n), .en(prng_en), .load_seed(load_seed),
        .seed_in(seed_in), .out(prng_data_int)
    );

`ifdef POWER_AWARE_SIM
    assign aes_state_out_raw = pd_aes_on ? aes_state_out_int : {128{1'bx}};
    assign aes_ready_raw     = pd_aes_on ? aes_ready_int     : 1'bx;
    assign aes_busy_raw      = pd_aes_on ? aes_busy_int      : 1'bx;
    assign prng_data_raw     = pd_aes_on ? prng_data_int     : {128{1'bx}};
`else
    assign aes_state_out_raw = pd_aes_on ? aes_state_out_int : 128'b0;
    assign aes_ready_raw     = pd_aes_on ? aes_ready_int     : 1'b0;
    assign aes_busy_raw      = pd_aes_on ? aes_busy_int      : 1'b0;
    assign prng_data_raw     = pd_aes_on ? prng_data_int     : 128'b0;
`endif
endmodule
