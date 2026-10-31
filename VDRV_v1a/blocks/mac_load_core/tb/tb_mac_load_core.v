`timescale 1ns / 1ps

module tb_mac_load_core;

    localparam ROWS        = 5;
    localparam COLS        = 4;
    localparam DATA_WIDTH  = 8;
    localparam ACC_WIDTH   = 16;
    localparam ITER_CYCLES = 10;

    reg          clk;
    reg          rst_n;
    reg          start;
    reg  [127:0] data_in;
    reg  [127:0] cfg_in;
    wire [127:0] data_out;
    wire         ready;

    // DUT Instantiation
    mac_load_core #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ITER_CYCLES(ITER_CYCLES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_in(data_in),
        .cfg_in(cfg_in),
        .data_out(data_out),
        .ready(ready)
    );

    // 100MHz clock (10ns period)
    always #5 clk = ~clk;

    // Helper task to execute a block and measure duration
    integer low_cycle_count;
    task execute_block(
        input  [127:0] d_in,
        input  [127:0] c_in,
        output [127:0] d_out,
        output integer elapsed_cycles
    );
        begin
            @(posedge clk);
            #1;
            data_in = d_in;
            cfg_in  = c_in;
            start   = 1'b1;

            @(posedge clk);
            #1;
            start   = 1'b0;

            // Wait until ready returns to 1
            low_cycle_count = 0;
            while (!ready) begin
                low_cycle_count = low_cycle_count + 1;
                @(posedge clk);
                #1;
            end

            d_out = data_out;
            elapsed_cycles = low_cycle_count;
        end
    endtask

    // Signature storage
    reg [127:0] sig1;
    reg [127:0] sig1_repeat;
    reg [127:0] sig_a;
    reg [127:0] sig_b;
    reg [127:0] sig_c;
    integer cycles_taken;

    initial begin
        $display("===============================================================");
        $display("[TB START] Verification of mac_load_core unit started");
        $display("===============================================================");

        clk     = 0;
        rst_n   = 0;
        start   = 0;
        data_in = 128'b0;
        cfg_in  = 128'b0;

        // -------------------------------------------------------------
        // Test 1: Reset Behavior Check
        // -------------------------------------------------------------
        $display("[TEST 1] Checking Reset State...");
        #25;
        if (ready !== 1'b1) begin
            $display("[FAIL] Expected ready == 1 during reset, got %b", ready);
            $finish(1);
        end
        if (data_out !== 128'b0) begin
            $display("[FAIL] Expected data_out == 0 during reset, got 0x%032h", data_out);
            $finish(1);
        end

        // Release reset
        rst_n = 1;
        #20;
        if (ready !== 1'b1) begin
            $display("[FAIL] Expected ready == 1 after reset release, got %b", ready);
            $finish(1);
        end
        $display("[PASS] Test 1: Reset behavior verified (ready=1, data_out=0).");

        // -------------------------------------------------------------
        // Test 2: Single Block Execution & Determinism
        // -------------------------------------------------------------
        $display("\n[TEST 2] Single Block Execution & Determinism Test...");
        execute_block(
            128'h0123_4567_89ab_cdef_fedc_ba98_7654_3210,
            128'ha5a5_5a5a_3c3c_c3c3_0f0f_f0f0_aaaa_5555,
            sig1,
            cycles_taken
        );

        $display("  Single Block Run 1: Latency = %0d cycles (expected %0d)", cycles_taken, ITER_CYCLES);
        $display("  Output Signature  : 0x%032h", sig1);

        if (cycles_taken !== ITER_CYCLES) begin
            $display("[FAIL] Cycle count mismatch: expected %0d, got %0d", ITER_CYCLES, cycles_taken);
            $finish(1);
        end
        if (sig1 === 128'b0) begin
            $display("[FAIL] Output signature must be non-zero!");
            $finish(1);
        end

        // Re-run with identical input to verify determinism
        @(posedge clk);
        execute_block(
            128'h0123_4567_89ab_cdef_fedc_ba98_7654_3210,
            128'ha5a5_5a5a_3c3c_c3c3_0f0f_f0f0_aaaa_5555,
            sig1_repeat,
            cycles_taken
        );
        $display("  Single Block Run 2 (Determinism): Output = 0x%032h", sig1_repeat);

        if (sig1 !== sig1_repeat) begin
            $display("[FAIL] Output is non-deterministic: 0x%032h vs 0x%032h", sig1, sig1_repeat);
            $finish(1);
        end
        $display("[PASS] Test 2: Single block execution verified (exact %0d cycles, deterministic non-zero signature).", ITER_CYCLES);

        // -------------------------------------------------------------
        // Test 3: Continuous Back-to-Back Execution
        // -------------------------------------------------------------
        $display("\n[TEST 3] Continuous Back-to-Back Multi-Block Execution...");
        // Block A
        execute_block(
            128'h1111_2222_3333_4444_5555_6666_7777_8888,
            128'hdead_beef_cafe_babe_0123_4567_89ab_cdef,
            sig_a,
            cycles_taken
        );
        if (cycles_taken !== ITER_CYCLES) begin
            $display("[FAIL] Block A cycle count mismatch: %0d", cycles_taken);
            $finish(1);
        end
        $display("  Block A Result: 0x%032h (cycles: %0d)", sig_a, cycles_taken);

        // Block B immediately back-to-back
        execute_block(
            128'haaaa_bbbb_cccc_dddd_eeee_ffff_0000_1111,
            128'h1357_9bdf_2468_ace0_f0e1_d2c3_b4a5_9687,
            sig_b,
            cycles_taken
        );
        if (cycles_taken !== ITER_CYCLES) begin
            $display("[FAIL] Block B cycle count mismatch: %0d", cycles_taken);
            $finish(1);
        end
        $display("  Block B Result: 0x%032h (cycles: %0d)", sig_b, cycles_taken);

        // Block C immediately back-to-back
        execute_block(
            128'hffff_eeee_dddd_cccc_bbbb_aaaa_9999_8888,
            128'h0102_0304_0506_0708_090a_0b0c_0d0e_0f10,
            sig_c,
            cycles_taken
        );
        if (cycles_taken !== ITER_CYCLES) begin
            $display("[FAIL] Block C cycle count mismatch: %0d", cycles_taken);
            $finish(1);
        end
        $display("  Block C Result: 0x%032h (cycles: %0d)", sig_c, cycles_taken);

        // Verify distinct signatures
        if (sig_a === sig_b || sig_b === sig_c || sig_a === sig_c) begin
            $display("[FAIL] Signature collision detected across different input patterns!");
            $finish(1);
        end
        if (sig_a === 128'b0 || sig_b === 128'b0 || sig_c === 128'b0) begin
            $display("[FAIL] One of the block results is zero!");
            $finish(1);
        end

        $display("[PASS] Test 3: Continuous back-to-back execution verified with distinct signatures.");

        $display("\n===============================================================");
        $display("[TB SUCCESS] ALL mac_load_core UNIT TESTS PASSED");
        $display("===============================================================\n");
        $finish(0);
    end

endmodule
