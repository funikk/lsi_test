`timescale 1ns/1ps

module tb_crc_load_core;

    localparam CHANNELS     = 4;
    localparam UNROLL_STEPS = 48;
    localparam ITER_CYCLES  = 10;

    reg          clk;
    reg          rst_n;
    reg          start;
    reg  [127:0] data_in;
    reg  [127:0] cfg_in;
    wire [127:0] data_out;
    wire         ready;

    // DUT instantiation
    crc_load_core #(
        .CHANNELS(CHANNELS),
        .UNROLL_STEPS(UNROLL_STEPS),
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

    // Clock generation: 100MHz (10ns period)
    always #5 clk = ~clk;

    // Test vectors
    localparam [127:0] VEC_DATA_A = 128'h0123456789ABCDEF0011223344556677;
    localparam [127:0] VEC_CFG_A  = 128'hFEDCBA9876543210FFEECCBBAA998877;

    localparam [127:0] VEC_DATA_B = 128'h0123456789ABCDEF0011223344556678; // 1-bit flip
    localparam [127:0] VEC_CFG_B  = 128'hFEDCBA9876543210FFEECCBBAA998878; // 1-bit flip

    localparam [127:0] VEC_DATA_C = 128'hA5A5A5A55A5A5A5A0F0F0F0FF0F0F0F0;
    localparam [127:0] VEC_CFG_C  = 128'h3333CCCC5555AAAA0123456789ABCDEF;

    reg [127:0] result_a1;
    reg [127:0] result_a2;
    reg [127:0] result_data_flip;
    reg [127:0] result_cfg_flip;
    reg [127:0] result_c;

    integer cycle_count;
    integer errors;

    initial begin
        clk         = 0;
        rst_n       = 0;
        start       = 0;
        data_in     = 128'b0;
        cfg_in      = 128'b0;
        errors      = 0;
        cycle_count = 0;

        $display("================================================================");
        $display("[TB START] Starting comprehensive unit test for crc_load_core");
        $display("================================================================");

        // -------------------------------------------------------------
        // Test 1: Reset behavior check
        // -------------------------------------------------------------
        #25;
        if (ready !== 1'b1) begin
            $display("[FAIL] Test 1: ready is not 1 while in reset.");
            errors = errors + 1;
        end
        if (data_out !== 128'b0) begin
            $display("[FAIL] Test 1: data_out is not 0 while in reset.");
            errors = errors + 1;
        end

        @(negedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        #1;

        if (ready !== 1'b1) begin
            $display("[FAIL] Test 1: ready is not 1 after reset deassertion.");
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 1: Reset state verified (ready == 1, data_out == 0).");
        end

        // -------------------------------------------------------------
        // Test 2: Single block execution & 10-cycle execution timing
        // -------------------------------------------------------------
        @(posedge clk);
        data_in = VEC_DATA_A;
        cfg_in  = VEC_CFG_A;
        start   = 1'b1;

        @(posedge clk);
        start = 1'b0;
        cycle_count = 0;

        // Monitor ready low duration
        while (ready === 1'b0) begin
            cycle_count = cycle_count + 1;
            @(posedge clk);
        end

        #1;
        $display("[INFO] Block A execution finished. Low cycle duration = %0d cycles.", cycle_count);
        if (cycle_count !== ITER_CYCLES) begin
            $display("[FAIL] Test 2: Execution cycle count mismatch! Expected %0d, got %0d",
                     ITER_CYCLES, cycle_count);
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 2: Handshake timing verified (exactly %0d cycles low).", ITER_CYCLES);
        end

        if (data_out === 128'b0) begin
            $display("[FAIL] Test 2: data_out is zero after computation!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 2: data_out is non-zero (0x%032h)", data_out);
        end
        result_a1 = data_out;

        // -------------------------------------------------------------
        // Test 3: Determinism check (repeat with identical inputs)
        // -------------------------------------------------------------
        #20;
        @(posedge clk);
        data_in = VEC_DATA_A;
        cfg_in  = VEC_CFG_A;
        start   = 1'b1;

        @(posedge clk);
        start = 1'b0;

        while (ready === 1'b0) @(posedge clk);
        #1;
        result_a2 = data_out;

        if (result_a1 !== result_a2) begin
            $display("[FAIL] Test 3: Determinism failed! a1=0x%032h, a2=0x%032h", result_a1, result_a2);
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 3: Deterministic computation verified across identical runs.");
        end

        // -------------------------------------------------------------
        // Test 4: Sensitivity to data_in (1-bit change)
        // -------------------------------------------------------------
        @(posedge clk);
        data_in = VEC_DATA_B;
        cfg_in  = VEC_CFG_A;
        start   = 1'b1;

        @(posedge clk);
        start = 1'b0;

        while (ready === 1'b0) @(posedge clk);
        #1;
        result_data_flip = data_out;

        if (result_data_flip === result_a1) begin
            $display("[FAIL] Test 4: data_in sensitivity failed! Output unchanged on 1-bit input flip.");
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 4: data_in sensitivity confirmed. Output changed significantly.");
            $display("       A1:        0x%032h", result_a1);
            $display("       Data_flip: 0x%032h", result_data_flip);
        end

        // -------------------------------------------------------------
        // Test 5: Sensitivity to cfg_in (1-bit change)
        // -------------------------------------------------------------
        @(posedge clk);
        data_in = VEC_DATA_A;
        cfg_in  = VEC_CFG_B;
        start   = 1'b1;

        @(posedge clk);
        start = 1'b0;

        while (ready === 1'b0) @(posedge clk);
        #1;
        result_cfg_flip = data_out;

        if (result_cfg_flip === result_a1 || result_cfg_flip === result_data_flip) begin
            $display("[FAIL] Test 5: cfg_in sensitivity failed! Output did not change on cfg flip.");
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 5: cfg_in sensitivity confirmed. Output changed significantly.");
            $display("       A1:       0x%032h", result_a1);
            $display("       Cfg_flip: 0x%032h", result_cfg_flip);
        end

        // -------------------------------------------------------------
        // Test 6: Back-to-back continuous execution
        // -------------------------------------------------------------
        $display("[INFO] Starting Test 6: Back-to-back continuous block execution...");
        @(posedge clk);
        data_in = VEC_DATA_A;
        cfg_in  = VEC_CFG_A;
        start   = 1'b1;

        @(posedge clk);
        start = 1'b0;

        // Wait until ready becomes 1
        while (ready === 1'b0) @(posedge clk);

        // Immediate next posedge: assert start for Block C without extra idle delay
        data_in = VEC_DATA_C;
        cfg_in  = VEC_CFG_C;
        start   = 1'b1;

        @(posedge clk);
        start = 1'b0;
        cycle_count = 0;

        while (ready === 1'b0) begin
            cycle_count = cycle_count + 1;
            @(posedge clk);
        end

        #1;
        result_c = data_out;
        if (cycle_count !== ITER_CYCLES) begin
            $display("[FAIL] Test 6: Back-to-back Block C cycle count mismatch! Got %0d", cycle_count);
            errors = errors + 1;
        end else if (result_c === 128'b0 || result_c === result_a1) begin
            $display("[FAIL] Test 6: Back-to-back Block C invalid result: 0x%032h", result_c);
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 6: Back-to-back execution succeeded cleanly.");
            $display("       Result C: 0x%032h", result_c);
        end

        // -------------------------------------------------------------
        // Final Summary
        // -------------------------------------------------------------
        $display("================================================================");
        if (errors == 0) begin
            $display("[ALL TESTS PASSED] crc_load_core unit verification SUCCESSFUL!");
            $display("================================================================");
            $finish(0);
        end else begin
            $display("[TESTS FAILED] Total errors: %0d", errors);
            $display("================================================================");
            $fatal(1, "crc_load_core unit verification failed");
        end
    end

endmodule
