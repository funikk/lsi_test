`timescale 1ns / 1ps

module tb_aes_prng;

    reg clk;
    reg rst_n;
    reg start_motif;
    wire [127:0] ciphertext_out;
    wire ready_out;

    // Instantiate Top Module
    aes_prng_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_motif(start_motif),
        .ciphertext_out(ciphertext_out),
        .ready_out(ready_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Test sequence
    initial begin
        $dumpfile("tb_aes_prng.vcd");
        $dumpvars(0, tb_aes_prng);

        rst_n = 0;
        start_motif = 0;

        #20;
        rst_n = 1;

        #10;
        start_motif = 1;
        #10;
        start_motif = 0;

        // Let it run for multiple AES encryptions (each takes 11 clock cycles)
        #1500;

        $display("Simulation finished.");
        $finish;
    end

    // Monitor output to check transitions
    always @(posedge clk) begin
        if (ready_out) begin
            $display("[Time %0t] ready_out = 1, Ciphertext = %h", $time, ciphertext_out);
        end
    end

endmodule
