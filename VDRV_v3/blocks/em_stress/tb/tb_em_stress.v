`timescale 1ns/1ps

module tb_em_stress;

    parameter W = 32;
    parameter FANOUT = 64;

    reg         clk;
    reg         rst_n;
    reg         mmio_valid;
    reg  [7:0]  mmio_addr;
    reg  [3:0]  mmio_wstrb;
    reg  [31:0] mmio_wdata;
    wire [31:0] mmio_rdata;
    wire        mmio_ready;

    reg         hw_direct_active;
    reg  [2:0]  hw_em_ctrl;

    em_stress #(
        .W(W),
        .FANOUT(FANOUT)
    ) dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .mmio_valid       (mmio_valid),
        .mmio_addr        (mmio_addr),
        .mmio_wstrb       (mmio_wstrb),
        .mmio_wdata       (mmio_wdata),
        .mmio_rdata       (mmio_rdata),
        .mmio_ready       (mmio_ready),
        .hw_direct_active (hw_direct_active),
        .hw_em_ctrl       (hw_em_ctrl)
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
    reg [W-1:0] prev_tx, prev_rx;
    reg [FANOUT-1:0] prev_sink;
    reg prev_src;
    reg [31:0] prev_sig, cur_sig;
    reg test_err;
    integer step;

    initial begin
        test_err = 0;
        clk = 0;
        rst_n = 0;
        mmio_valid = 0;
        mmio_addr = 0;
        mmio_wstrb = 0;
        mmio_wdata = 0;
        hw_direct_active = 0;
        hw_em_ctrl = 3'b000;

        // Reset check
        #15;
        if (dut.u_rx.rx_data !== 32'h0000_0000) begin
            $display("[FAIL] RX reset value mismatch: expected 0x0, got 0x%08x", dut.u_rx.rx_data);
            test_err = 1;
        end else begin
            $display("[PASS] RX reset value = 0x%08x", dut.u_rx.rx_data);
        end

        #10;
        rst_n = 1;
        #20;

        $display("[INFO] Starting em_stress tests...");

        // 1. Reset values check
        if (dut.u_tx.tx_data !== 32'h5555_5555) begin
            $display("[FAIL] TX reset value mismatch: expected 0x55555555, got 0x%08x", dut.u_tx.tx_data);
            test_err = 1;
        end else begin
            $display("[PASS] TX reset value = 0x%08x (alternating 0101...)", dut.u_tx.tx_data);
        end

        // 2. Bus EN pattern 0 (alternating toggle)
        mmio_write(8'h00, 32'h0000_0001); // bus_en=1, fo_en=0, pattern=0
        @(posedge clk);

        // Check for 6 cycles that tx flips every bit every cycle and rx follows 1 cycle later
        for (step = 0; step < 6; step = step + 1) begin
            prev_tx = dut.u_tx.tx_data;
            prev_rx = dut.u_rx.rx_data;
            @(posedge clk);
            if (dut.u_tx.tx_data !== ~prev_tx) begin
                $display("[FAIL] TX did not toggle all bits at step %0d! prev=0x%08x, cur=0x%08x",
                         step, prev_tx, dut.u_tx.tx_data);
                test_err = 1;
            end
            if (dut.u_rx.rx_data !== prev_tx) begin
                $display("[FAIL] RX did not follow TX 1 cycle later at step %0d! expected=0x%08x, got=0x%08x",
                         step, prev_tx, dut.u_rx.rx_data);
                test_err = 1;
            end
        end
        $display("[PASS] Pattern 0: TX toggles every bit every cycle, RX follows 1 cycle later");

        // 3. Pattern 1 (LFSR)
        mmio_write(8'h00, 32'h0000_0005); // bus_en=1, fo_en=0, pattern=1 (bit 2=1)
        @(posedge clk);
        for (step = 0; step < 6; step = step + 1) begin
            prev_tx = dut.u_tx.tx_data;
            @(posedge clk);
            if (dut.u_tx.tx_data === prev_tx || dut.u_tx.tx_data === ~prev_tx) begin
                $display("[FAIL] Pattern 1 LFSR not advancing properly at step %0d: cur=0x%08x",
                         step, dut.u_tx.tx_data);
                test_err = 1;
            end
            if (dut.u_rx.rx_data !== prev_tx) begin
                $display("[FAIL] Pattern 1 RX did not follow TX! expected=0x%08x, got=0x%08x",
                         prev_tx, dut.u_rx.rx_data);
                test_err = 1;
            end
        end
        $display("[PASS] Pattern 1: LFSR changes dynamically and RX follows 1 cycle later");

        // 4. Everything disabled -> static check
        mmio_write(8'h00, 32'h0000_0000); // bus_en=0, fo_en=0
        repeat (2) @(posedge clk);
        prev_tx   = dut.u_tx.tx_data;
        prev_rx   = dut.u_rx.rx_data;
        prev_src  = dut.u_fo.src;
        prev_sink = dut.u_fo.sink;
        mmio_read(8'h04, prev_sig);

        repeat (5) @(posedge clk);
        mmio_read(8'h04, cur_sig);

        if (dut.u_tx.tx_data !== prev_tx || dut.u_rx.rx_data !== prev_rx ||
            dut.u_fo.src !== prev_src || dut.u_fo.sink !== prev_sink ||
            cur_sig !== prev_sig) begin
            $display("[FAIL] Logic changed while disabled! prev_sig=0x%08x, cur_sig=0x%08x",
                     prev_sig, cur_sig);
            test_err = 1;
        end else begin
            $display("[PASS] When everything disabled: TX, RX, Fanout net, and EM_SIG are all static");
        end

        // 5. Fanout net enable test
        mmio_write(8'h00, 32'h0000_0002); // bus_en=0, fo_en=1
        @(posedge clk);
        begin : test_fanout_loop
            reg sink_toggled;
            sink_toggled = 0;
            for (step = 0; step < 8; step = step + 1) begin
                prev_src  = dut.u_fo.src;
                prev_sink = dut.u_fo.sink;
                @(posedge clk);
                if (dut.u_fo.src !== ~prev_src) begin
                    $display("[FAIL] Fanout src did not toggle at step %0d", step);
                    test_err = 1;
                end
                if (dut.u_fo.sink !== prev_sink) begin
                    sink_toggled = 1;
                end
            end
            if (!sink_toggled) begin
                $display("[FAIL] Fanout sink did not toggle over 8 cycles!");
                test_err = 1;
            end else begin
                $display("[PASS] Fanout net toggles when enabled (src flips and sink updates)");
            end
        end

        // Check EM_SIG changes when fanout enabled
        mmio_read(8'h04, prev_sig);
        repeat (3) @(posedge clk);
        mmio_read(8'h04, cur_sig);
        if (cur_sig === prev_sig) begin
            $display("[FAIL] EM_SIG did not change while fanout enabled!");
            test_err = 1;
        end else begin
            $display("[PASS] EM_SIG changes when enabled (0x%08x -> 0x%08x)", prev_sig, cur_sig);
        end

        // Disable fanout and check static
        mmio_write(8'h00, 32'h0000_0000);
        repeat (2) @(posedge clk);
        prev_src  = dut.u_fo.src;
        prev_sink = dut.u_fo.sink;
        mmio_read(8'h04, prev_sig);
        repeat (5) @(posedge clk);
        mmio_read(8'h04, cur_sig);
        if (dut.u_fo.src !== prev_src || dut.u_fo.sink !== prev_sink || cur_sig !== prev_sig) begin
            $display("[FAIL] Fanout net or EM_SIG moved after disable!");
            test_err = 1;
        end else begin
            $display("[PASS] Fanout net is static when disabled");
        end

        // 6. hw_direct_active override test
        // EM_CTRL MMIO is 0. Assert hw_direct_active with hw_em_ctrl = 3'b001 (bus_en=1, pattern=0)
        hw_em_ctrl = 3'b001;
        hw_direct_active = 1;
        @(posedge clk);
        prev_tx = dut.u_tx.tx_data;
        @(posedge clk);
        if (dut.u_tx.tx_data !== ~prev_tx) begin
            $display("[FAIL] hw_direct_active override failed to activate bus toggle!");
            test_err = 1;
        end else begin
            $display("[PASS] hw_direct_active override active: TX toggles");
        end

        hw_direct_active = 0;
        @(posedge clk);
        prev_tx = dut.u_tx.tx_data;
        repeat (3) @(posedge clk);
        if (dut.u_tx.tx_data !== prev_tx) begin
            $display("[FAIL] TX kept toggling after hw_direct_active deasserted!");
            test_err = 1;
        end else begin
            $display("[PASS] hw_direct_active deasserted: returned to MMIO (disabled)");
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
