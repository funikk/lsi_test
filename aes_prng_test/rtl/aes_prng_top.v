module aes_prng_top(
    input wire clk,
    input wire rst_n,
    input wire start_motif,
    output wire [127:0] ciphertext_out,
    output wire ready_out
);

    // PRNG outputs
    wire [127:0] prng_data;
    wire [127:0] prng_key;

    // Plaintext PRNG
    lfsr_prng u_prng_data (
        .clk(clk),
        .rst_n(rst_n),
        .en(ready_out | start_motif),
        .out(prng_data)
    );

    // Key PRNG
    lfsr_prng u_prng_key (
        .clk(clk),
        .rst_n(rst_n),
        .en(ready_out | start_motif),
        .out(prng_key)
    );

    // AES Core start trigger register
    reg aes_start;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aes_start <= 1'b0;
        end else begin
            aes_start <= (start_motif | ready_out);
        end
    end

    // AES Core Instance
    aes_core u_aes (
        .clk(clk),
        .rst_n(rst_n),
        .start(aes_start),
        .state_in(prng_data),
        .key_in(prng_key),
        .state_out(ciphertext_out),
        .ready(ready_out)
    );

endmodule
