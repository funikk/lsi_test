`timescale 1ns/1ps

module tb_sys_ctrl;

    reg         clk;
    reg         rst_n;
    reg         mmio_valid;
    reg  [7:0]  mmio_addr;
    reg  [3:0]  mmio_wstrb;
    reg  [31:0] mmio_wdata;
    wire [31:0] mmio_rdata;
    wire        mmio_ready;

    reg  [3:0]  scenario_sel;
    wire        scenario_done;
    wire        sig_ok;
    wire [1:0]  sw_marker;
    wire [7:0]  sig_out;

    sys_ctrl dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .mmio_valid    (mmio_valid),
        .mmio_addr     (mmio_addr),
        .mmio_wstrb    (mmio_wstrb),
        .mmio_wdata    (mmio_wdata),
        .mmio_rdata    (mmio_rdata),
        .mmio_ready    (mmio_ready),
        .scenario_sel  (scenario_sel),
        .scenario_done (scenario_done),
        .sig_ok        (sig_ok),
        .sw_marker     (sw_marker),
        .sig_out       (sig_out)
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
    reg [31:0] c1, c2;
    reg test_err;

    initial begin
        test_err = 0;
        clk = 0;
        rst_n = 0;
        mmio_valid = 0;
        mmio_addr = 0;
        mmio_wstrb = 0;
        mmio_wdata = 0;
        scenario_sel = 4'h0;

        // Reset
        #25;
        rst_n = 1;
        #20;

        $display("[INFO] Starting sys_ctrl tests...");

        // 1. Initial output check
        if (scenario_done !== 1'b0 || sig_ok !== 1'b0 || sw_marker !== 2'b00 || sig_out !== 8'h00) begin
            $display("[FAIL] Initial output reset values mismatch: done=%b sig_ok=%b marker=%b sig_out=0x%02x",
                     scenario_done, sig_ok, sw_marker, sig_out);
            test_err = 1;
        end else begin
            $display("[PASS] Reset values for outputs verified");
        end

        // 2. Scenario synchronizer and readback
        scenario_sel = 4'hA;
        // Wait at least 3 clock cycles for 2-stage FF synchronization
        repeat (4) @(posedge clk);
        mmio_read(8'h00, rdata);
        if (rdata[3:0] !== 4'hA) begin
            $display("[FAIL] SCENARIO readback mismatch: expected 0xA, got 0x%01x", rdata[3:0]);
            test_err = 1;
        end else begin
            $display("[PASS] SCENARIO readback 0xA verified");
        end

        scenario_sel = 4'h5;
        repeat (4) @(posedge clk);
        mmio_read(8'h00, rdata);
        if (rdata[3:0] !== 4'h5) begin
            $display("[FAIL] SCENARIO readback mismatch: expected 0x5, got 0x%01x", rdata[3:0]);
            test_err = 1;
        end else begin
            $display("[PASS] SCENARIO readback 0x5 verified");
        end

        // 3. STATUS register and outputs (scenario_done, sig_ok)
        mmio_write(8'h04, 32'h0000_0001); // scenario_done=1, sig_ok=0
        @(posedge clk);
        if (scenario_done !== 1'b1 || sig_ok !== 1'b0) begin
            $display("[FAIL] STATUS output drive failed: done=%b sig_ok=%b", scenario_done, sig_ok);
            test_err = 1;
        end else begin
            $display("[PASS] STATUS output drive (done=1, ok=0) verified");
        end
        mmio_read(8'h04, rdata);
        if (rdata[1:0] !== 2'b01) begin
            $display("[FAIL] STATUS readback mismatch: expected 2'b01, got %b", rdata[1:0]);
            test_err = 1;
        end else begin
            $display("[PASS] STATUS readback 2'b01 verified");
        end

        mmio_write(8'h04, 32'h0000_0003); // scenario_done=1, sig_ok=1
        @(posedge clk);
        if (scenario_done !== 1'b1 || sig_ok !== 1'b1) begin
            $display("[FAIL] STATUS output drive failed: done=%b sig_ok=%b", scenario_done, sig_ok);
            test_err = 1;
        end
        mmio_read(8'h04, rdata);
        if (rdata[1:0] !== 2'b11) begin
            $display("[FAIL] STATUS readback mismatch: expected 2'b11, got %b", rdata[1:0]);
            test_err = 1;
        end else begin
            $display("[PASS] STATUS (done=1, ok=1) verified");
        end

        // 4. MARKER register and output (sw_marker)
        mmio_write(8'h08, 32'h0000_0002);
        @(posedge clk);
        if (sw_marker !== 2'b10) begin
            $display("[FAIL] MARKER output drive failed: marker=%b", sw_marker);
            test_err = 1;
        end
        mmio_read(8'h08, rdata);
        if (rdata[1:0] !== 2'b10) begin
            $display("[FAIL] MARKER readback mismatch: expected 2'b10, got %b", rdata[1:0]);
            test_err = 1;
        end else begin
            $display("[PASS] MARKER output drive and readback (2'b10) verified");
        end

        // 5. SIG_OUT register and output (sig_out)
        mmio_write(8'h0C, 32'h0000_005A);
        @(posedge clk);
        if (sig_out !== 8'h5A) begin
            $display("[FAIL] SIG_OUT output drive failed: sig_out=0x%02x", sig_out);
            test_err = 1;
        end
        mmio_read(8'h0C, rdata);
        if (rdata[7:0] !== 8'h5A) begin
            $display("[FAIL] SIG_OUT readback mismatch: expected 0x5A, got 0x%02x", rdata[7:0]);
            test_err = 1;
        end else begin
            $display("[PASS] SIG_OUT output drive and readback (0x5A) verified");
        end

        // 6. Free-running CYCLE counter
        mmio_read(8'h10, c1);
        repeat (10) @(posedge clk);
        mmio_read(8'h10, c2);
        if (c2 <= c1) begin
            $display("[FAIL] CYCLE counter did not increment! c1=%d, c2=%d", c1, c2);
            test_err = 1;
        end else begin
            $display("[PASS] CYCLE counter incremented from %d to %d (delta=%d)", c1, c2, c2 - c1);
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
