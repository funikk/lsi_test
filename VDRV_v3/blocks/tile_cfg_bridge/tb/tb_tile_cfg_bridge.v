`timescale 1ns/1ps

module tb_tile_cfg_bridge;

    parameter NT = 6;

    reg                 clk;
    reg                 rst_n;
    reg                 mmio_valid;
    reg  [7:0]          mmio_addr;
    reg  [3:0]          mmio_wstrb;
    reg  [31:0]         mmio_wdata;
    wire [31:0]         mmio_rdata;
    wire                mmio_ready;

    wire                cfg_valid;
    wire [7:0]          cfg_tile_id;
    wire [4:0]          cfg_addr;
    wire [31:0]         cfg_wdata;
    wire                sw_pg_sync;
    wire [1:0]          sw_profile_id;
    reg  [NT*32-1:0]    tile_sig;

    tile_cfg_bridge #(.NT(NT)) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .mmio_valid    (mmio_valid),
        .mmio_addr     (mmio_addr),
        .mmio_wstrb    (mmio_wstrb),
        .mmio_wdata    (mmio_wdata),
        .mmio_rdata    (mmio_rdata),
        .mmio_ready    (mmio_ready),
        .cfg_valid     (cfg_valid),
        .cfg_tile_id   (cfg_tile_id),
        .cfg_addr      (cfg_addr),
        .cfg_wdata     (cfg_wdata),
        .sw_pg_sync    (sw_pg_sync),
        .sw_profile_id (sw_profile_id),
        .tile_sig      (tile_sig)
    );

    // Clock generator: 100MHz (10ns period)
    always #5 clk = ~clk;

    // Timeout watchdog
    initial begin
        #50000;
        $display("[ERROR] Simulation timeout!");
        $display("TEST FAILED");
        $finish(1);
    end

    // MMIO bus tasks
    task mmio_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            mmio_valid <= 1'b1;
            mmio_addr  <= addr;
            mmio_wstrb <= 4'hF;
            mmio_wdata <= data;
            @(posedge clk);
            while (!mmio_ready) @(posedge clk);
            mmio_valid <= 1'b0;
            mmio_wstrb <= 4'h0;
        end
    endtask

    task mmio_read(input [7:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            mmio_valid <= 1'b1;
            mmio_addr  <= addr;
            mmio_wstrb <= 4'h0;
            @(posedge clk);
            while (!mmio_ready) @(posedge clk);
            data = mmio_rdata;
            mmio_valid <= 1'b0;
        end
    endtask

    reg [31:0] rdata;
    reg [31:0] expected_xor;
    integer k;
    reg test_err;

    initial begin
        test_err = 0;
        clk = 0;
        rst_n = 0;
        mmio_valid = 0;
        mmio_addr = 0;
        mmio_wstrb = 0;
        mmio_wdata = 0;
        tile_sig = 0;

        // Reset
        #25;
        rst_n = 1;
        #20;

        $display("[INFO] Starting tile_cfg_bridge tests...");

        // 1. Check NUM_TILES
        mmio_read(8'h18, rdata);
        if (rdata !== NT) begin
            $display("[FAIL] NUM_TILES mismatch: expected %d, got %d", NT, rdata);
            test_err = 1;
        end else begin
            $display("[PASS] NUM_TILES readback = %d", rdata);
        end

        // 2. Check CFG_TARGET write/read and CFG_WDATA pulse
        // Write CFG_TARGET: tile_id = 8'h25, cfg_addr = 5'h0E
        mmio_write(8'h00, {19'd0, 5'h0E, 8'h25});
        mmio_read(8'h00, rdata);
        if (rdata !== {19'd0, 5'h0E, 8'h25}) begin
            $display("[FAIL] CFG_TARGET readback: expected 0x%08x, got 0x%08x", {19'd0, 5'h0E, 8'h25}, rdata);
            test_err = 1;
        end else begin
            $display("[PASS] CFG_TARGET readback = 0x%08x", rdata);
        end

        // Write CFG_WDATA and verify 1-cycle pulse
        @(posedge clk);
        mmio_valid <= 1'b1;
        mmio_addr  <= 8'h04;
        mmio_wstrb <= 4'hF;
        mmio_wdata <= 32'hCAFE_BABE;
        @(posedge clk);
        while (!mmio_ready) @(posedge clk);
        // mmio_ready is asserted here. Next cycle, cfg_valid should be asserted!
        if (cfg_valid !== 1'b1 || cfg_tile_id !== 8'h25 || cfg_addr !== 5'h0E || cfg_wdata !== 32'hCAFE_BABE) begin
            $display("[FAIL] CFG_WDATA pulse check failed! valid=%b tile_id=0x%02x addr=0x%02x wdata=0x%08x",
                     cfg_valid, cfg_tile_id, cfg_addr, cfg_wdata);
            test_err = 1;
        end else begin
            $display("[PASS] CFG_WDATA pulse asserted: valid=%b tile_id=0x%02x addr=0x%02x wdata=0x%08x",
                     cfg_valid, cfg_tile_id, cfg_addr, cfg_wdata);
        end
        mmio_valid <= 1'b0;
        mmio_wstrb <= 4'h0;
        @(posedge clk);
        // Next cycle: cfg_valid MUST be deasserted (1 cycle pulse)
        if (cfg_valid !== 1'b0) begin
            $display("[FAIL] cfg_valid stayed high after 1 cycle!");
            test_err = 1;
        end else begin
            $display("[PASS] cfg_valid exactly 1 cycle pulse");
        end

        // 3. Check CTRL register (sw_pg_sync and sw_profile_id)
        // Write CTRL with bit 0 = 1 (sync pulse), sw_profile_id = 2'b10: bits [5:4]=2'b10, [3:1]=0, [0]=1
        @(posedge clk);
        mmio_valid <= 1'b1;
        mmio_addr  <= 8'h08;
        mmio_wstrb <= 4'hF;
        mmio_wdata <= {26'd0, 2'b10, 3'd0, 1'b1};
        @(posedge clk);
        while (!mmio_ready) @(posedge clk);
        if (sw_pg_sync !== 1'b1 || sw_profile_id !== 2'b10) begin
            $display("[FAIL] CTRL pulse check failed! sync=%b profile_id=%b", sw_pg_sync, sw_profile_id);
            test_err = 1;
        end else begin
            $display("[PASS] CTRL pulse asserted: sync=%b profile_id=%b", sw_pg_sync, sw_profile_id);
        end
        mmio_valid <= 1'b0;
        mmio_wstrb <= 4'h0;
        @(posedge clk);
        // Next cycle: sw_pg_sync MUST be 0
        if (sw_pg_sync !== 1'b0) begin
            $display("[FAIL] sw_pg_sync stayed high after 1 cycle!");
            test_err = 1;
        end else begin
            $display("[PASS] sw_pg_sync exactly 1 cycle pulse");
        end

        // Read CTRL: bit 0 must read back 0, profile_id must be 2'b10 (0x00000020)
        mmio_read(8'h08, rdata);
        if (rdata !== {26'd0, 2'b10, 4'd0}) begin
            $display("[FAIL] CTRL readback mismatch: expected 0x%08x, got 0x%08x", {26'd0, 2'b10, 4'd0}, rdata);
            test_err = 1;
        end else begin
            $display("[PASS] CTRL readback bit0 is 0, profile_id is 2'b10: 0x%08x", rdata);
        end

        // Change profile_id to 2'b01 without pulse: bits [5:4]=2'b01, [3:0]=0 (0x00000010)
        mmio_write(8'h08, {26'd0, 2'b01, 4'd0});
        if (sw_pg_sync !== 1'b0 || sw_profile_id !== 2'b01) begin
            $display("[FAIL] CTRL without sync failed! sync=%b profile_id=%b", sw_pg_sync, sw_profile_id);
            test_err = 1;
        end else begin
            $display("[PASS] sw_profile_id updated to 2'b01 without sync");
        end
        mmio_read(8'h08, rdata);
        if (rdata !== {26'd0, 2'b01, 4'd0}) begin
            $display("[FAIL] CTRL profile_id readback mismatch: expected 0x%08x, got 0x%08x", {26'd0, 2'b01, 4'd0}, rdata);
            test_err = 1;
        end else begin
            $display("[PASS] CTRL profile_id readback 2'b01 verified");
        end

        // 4. Test SIG_SEL, SIG_DATA, and SIG_XOR
        tile_sig[0*32 +: 32] = 32'h1122_3344;
        tile_sig[1*32 +: 32] = 32'h5566_7788;
        tile_sig[2*32 +: 32] = 32'h99AA_BBCC;
        tile_sig[3*32 +: 32] = 32'hDDEE_FF00;
        tile_sig[4*32 +: 32] = 32'hA5A5_5A5A;
        tile_sig[5*32 +: 32] = 32'h1234_5678;

        expected_xor = 32'h1122_3344 ^ 32'h5566_7788 ^ 32'h99AA_BBCC ^
                        32'hDDEE_FF00 ^ 32'hA5A5_5A5A ^ 32'h1234_5678;

        // Check SIG_XOR
        mmio_read(8'h14, rdata);
        if (rdata !== expected_xor) begin
            $display("[FAIL] SIG_XOR mismatch: expected 0x%08x, got 0x%08x", expected_xor, rdata);
            test_err = 1;
        end else begin
            $display("[PASS] SIG_XOR = 0x%08x", rdata);
        end

        // Check SIG_SEL and SIG_DATA for each tile
        for (k = 0; k < NT; k = k + 1) begin
            mmio_write(8'h0C, k);
            mmio_read(8'h0C, rdata);
            if (rdata !== k) begin
                $display("[FAIL] SIG_SEL readback mismatch for %0d: got %0d", k, rdata);
                test_err = 1;
            end
            mmio_read(8'h10, rdata);
            if (rdata !== tile_sig[k*32 +: 32]) begin
                $display("[FAIL] SIG_DATA mismatch for tile %0d: expected 0x%08x, got 0x%08x",
                         k, tile_sig[k*32 +: 32], rdata);
                test_err = 1;
            end else begin
                $display("[PASS] Tile %0d SIG_DATA = 0x%08x verified", k, rdata);
            end
        end

        // Final result
        #20;
        if (test_err == 0) begin
            $display("========================================");
            $display("TEST PASSED");
            $display("========================================");
            $finish(0);
        end else begin
            $display("========================================");
            $display("TEST FAILED");
            $display("========================================");
            $finish(1);
        end
    end

endmodule
