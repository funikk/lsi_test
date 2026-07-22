`timescale 1ns / 1ps

module tb_aes_core;

    reg clk;
    reg rst_n;
    reg start;
    reg [127:0] state_in;
    reg [127:0] key_in;
    wire [127:0] state_out;
    wire ready;

    // DUT Instance
    aes_core u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .state_in(state_in),
        .key_in(key_in),
        .state_out(state_out),
        .ready(ready)
    );

    always #5 clk = ~clk;

    // FIPS-197 Test Vector:
    // Plaintext:  00112233445566778899aabbccddeeff
    // Key:        000102030405060708090a0b0c0d0e0f
    // Expected Ciphertext: 69c4e0d86a7b0430d8cdb78070b4c55a
    localparam [127:0] TEST_PLAINTEXT  = 128'h00112233445566778899aabbccddeeff;
    localparam [127:0] TEST_KEY        = 128'h000102030405060708090a0b0c0d0e0f;
    localparam [127:0] EXPECTED_CIPHER = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

    initial begin
        clk = 0;
        rst_n = 0;
        start = 0;
        state_in = 0;
        key_in = 0;

        #20;
        rst_n = 1;
        #10;

        // Pulse Start
        @(posedge clk);
        state_in = TEST_PLAINTEXT;
        key_in   = TEST_KEY;
        start    = 1'b1;

        @(posedge clk);
        start = 1'b0;

        // Wait for ready
        wait(ready);
        @(posedge clk);

        $display("\n=======================================================");
        $display("[UNIT SIM: aes_core] AES-128 Core Test Vector Results");
        $display("-------------------------------------------------------");
        $display("Plaintext:  0x%032h", TEST_PLAINTEXT);
        $display("Key:        0x%032h", TEST_KEY);
        $display("Output:     0x%032h", state_out);
        $display("Expected:   0x%032h", EXPECTED_CIPHER);

        if (state_out === EXPECTED_CIPHER) begin
            $display("[UNIT TEST PASSED] AES-128 Core Encryption Verified!");
            $display("=======================================================\n");
            $finish;
        end else begin
            $display("[UNIT TEST FAILED] Ciphertext Mismatch!");
            $display("=======================================================\n");
            $fatal(1, "AES-128 core unit verification failed");
        end
    end

endmodule
