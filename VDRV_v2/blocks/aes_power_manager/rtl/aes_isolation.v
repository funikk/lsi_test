module aes_isolation (
    input  wire         isolate,
    input  wire [127:0] aes_state_out_raw,
    input  wire         aes_ready_raw,
    input  wire         aes_busy_raw,
    input  wire [127:0] prng_data_raw,
    output wire [127:0] aes_state_out,
    output wire         aes_ready,
    output wire         aes_busy,
    output wire [127:0] prng_data
);
    assign aes_state_out = isolate ? 128'b0 : aes_state_out_raw;
    assign aes_ready     = isolate ? 1'b0   : aes_ready_raw;
    assign aes_busy      = isolate ? 1'b0   : aes_busy_raw;
    assign prng_data     = isolate ? 128'b0 : prng_data_raw;
endmodule
