`timescale 1ns / 1ps

module tb_lfsr_prng_ctrl;

    reg clk;
    reg rst_n;
    reg en;
    reg load_seed;
    reg [127:0] seed_in;
    wire [127:0] out;

    // DUT Instance
    lfsr_prng_ctrl u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .load_seed(load_seed),
        .seed_in(seed_in),
        .out(out)
    );

    always #5 clk = ~clk;

    localparam [127:0] TEST_SEED = 128'h89ABCDEF012345675A5A5A5AA5A5A5A5;

    initial begin
        clk = 0;
        rst_n = 0;
        en = 0;
        load_seed = 0;
        seed_in = 0;

        #20;
        rst_n = 1;
        #10;

        // Step 1: Load Seed
        @(posedge clk);
        seed_in = TEST_SEED;
        load_seed = 1'b1;

        @(posedge clk);
        load_seed = 1'b0;
        #1; // Wait for non-blocking register assignment

        $display("[UNIT SIM: lfsr_prng] Loaded Seed = 0x%032h", TEST_SEED);

        if (out !== TEST_SEED) begin
            $display("[UNIT TEST FAILED] Seed load failed! Got 0x%032h", out);
            $fatal(1, "LFSR seed load verification failed");
        end

        // Step 2: Enable PRNG shift for 5 cycles and check values change
        @(posedge clk);
        en = 1'b1;

        repeat (5) @(posedge clk);
        en = 1'b0;
        #1;

        $display("[UNIT SIM: lfsr_prng] PRNG Output after 5 shifts = 0x%032h", out);

        if (out !== TEST_SEED && out !== 128'b0) begin
            $display("[UNIT TEST PASSED] LFSR PRNG Seed Load & Shift Output Verified!");
            $finish;
        end else begin
            $display("[UNIT TEST FAILED] LFSR Output did not evolve!");
            $fatal(1, "LFSR shift verification failed");
        end
    end

endmodule
