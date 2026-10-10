`timescale 1ns/1ps
`include "defines.vh"

module tb_pwr_manager;

    localparam G = 4;
    localparam CLK_PERIOD = 10;

    reg clk;
    reg rst_n;

    // MMIO
    reg        mmio_valid;
    reg [7:0]  mmio_addr;
    reg [3:0]  mmio_wstrb;
    reg [31:0] mmio_wdata;
    wire [31:0] mmio_rdata;
    wire        mmio_ready;

    // Load Sequencer direct hardware request
    reg       hw_direct_active;
    reg [7:0] hw_pd_req;

    // DUT outputs / inputs
    wire [G-1:0] sw_trickle_en;
    wire [G-1:0] sw_trickle_ack;
    wire [G-1:0] sw_main_en;
    wire [G-1:0] sw_main_ack;
    wire [G-1:0] iso_en;
    wire [G-1:0] pd_rst_n;
    wire [G-1:0] pd_on;

    // Error counter
    integer errors = 0;

    // Cycle counter
    reg [31:0] cycle_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cycle_cnt <= 32'd0;
        else        cycle_cnt <= cycle_cnt + 32'd1;
    end

    // DUT instantiation
    pwr_manager #(
        .G(G)
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
        .hw_pd_req        (hw_pd_req),
        .sw_trickle_en    (sw_trickle_en),
        .sw_trickle_ack   (sw_trickle_ack),
        .sw_main_en       (sw_main_en),
        .sw_main_ack      (sw_main_ack),
        .iso_en           (iso_en),
        .pd_rst_n         (pd_rst_n),
        .pd_on            (pd_on)
    );

    // Power switch behavioral models (DELAY=8)
    genvar gi;
    generate
        for (gi = 0; gi < G; gi = gi + 1) begin : gen_sw_models
            vdrv_pwr_switch_model #(.DELAY(8)) u_sw_tr_model (
                .clk   (clk),
                .rst_n (rst_n),
                .en    (sw_trickle_en[gi]),
                .ack   (sw_trickle_ack[gi])
            );
            vdrv_pwr_switch_model #(.DELAY(8)) u_sw_mn_model (
                .clk   (clk),
                .rst_n (rst_n),
                .en    (sw_main_en[gi]),
                .ack   (sw_main_ack[gi])
            );
        end
    endgenerate

    // Clock generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Watchdog
    initial begin
        #(CLK_PERIOD * 50000);
        $display("[ERROR] Simulation timed out!");
        $display("TEST FAILED");
        $finish(1);
    end

    // Signal history for edge detection
    reg [G-1:0] prev_tr_en;
    reg [G-1:0] prev_tr_ack;
    reg [G-1:0] prev_mn_en;
    reg [G-1:0] prev_rst_n;
    reg [G-1:0] prev_iso_en;

    integer tr_rise_cycle [0:G-1];
    integer tr_ack_cycle  [0:G-1];
    integer mn_rise_cycle [0:G-1];
    integer rst_rel_cycle [0:G-1];
    integer iso_rel_cycle [0:G-1];
    integer iso_assert_cycle [0:G-1];
    integer rst_assert_cycle [0:G-1];
    integer sw_off_cycle     [0:G-1];

    integer k;
    initial begin
        for (k = 0; k < G; k = k + 1) begin
            tr_rise_cycle[k]    = -1;
            tr_ack_cycle[k]     = -1;
            mn_rise_cycle[k]    = -1;
            rst_rel_cycle[k]    = -1;
            iso_rel_cycle[k]    = -1;
            iso_assert_cycle[k] = -1;
            rst_assert_cycle[k] = -1;
            sw_off_cycle[k]     = -1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_tr_en   <= {G{1'b0}};
            prev_tr_ack  <= {G{1'b0}};
            prev_mn_en   <= {G{1'b0}};
            prev_rst_n   <= {G{1'b0}};
            prev_iso_en  <= {G{1'b1}};
        end else begin
            prev_tr_en   <= sw_trickle_en;
            prev_tr_ack  <= sw_trickle_ack;
            prev_mn_en   <= sw_main_en;
            prev_rst_n   <= pd_rst_n;
            prev_iso_en  <= iso_en;

            for (k = 0; k < G; k = k + 1) begin
                if (sw_trickle_en[k] && !prev_tr_en[k])
                    tr_rise_cycle[k] <= cycle_cnt;
                if (sw_trickle_ack[k] && !prev_tr_ack[k])
                    tr_ack_cycle[k] <= cycle_cnt;
                if (sw_main_en[k] && !prev_mn_en[k])
                    mn_rise_cycle[k] <= cycle_cnt;
                if (pd_rst_n[k] && !prev_rst_n[k])
                    rst_rel_cycle[k] <= cycle_cnt;
                if (!iso_en[k] && prev_iso_en[k])
                    iso_rel_cycle[k] <= cycle_cnt;

                if (iso_en[k] && !prev_iso_en[k])
                    iso_assert_cycle[k] <= cycle_cnt;
                if (!pd_rst_n[k] && prev_rst_n[k])
                    rst_assert_cycle[k] <= cycle_cnt;
                if (!sw_main_en[k] && prev_mn_en[k])
                    sw_off_cycle[k] <= cycle_cnt;
            end
        end
    end

    // MMIO Driver Tasks
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

    reg [31:0] read_val;

    initial begin
        $dumpfile("pwr_manager_tb.vcd");
        $dumpvars(0, tb_pwr_manager);

        // Initialization
        clk              = 0;
        rst_n            = 0;
        mmio_valid       = 0;
        mmio_addr        = 0;
        mmio_wstrb       = 0;
        mmio_wdata       = 0;
        hw_direct_active = 0;
        hw_pd_req        = 0;

        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("==================================================");
        $display("[TEST 1] Reset Values Check");
        $display("==================================================");
        if (iso_en !== 4'b1111) begin
            $display("[FAIL] Expected iso_en = 4'b1111, got %b", iso_en);
            errors = errors + 1;
        end
        if (pd_rst_n !== 4'b0000) begin
            $display("[FAIL] Expected pd_rst_n = 4'b0000, got %b", pd_rst_n);
            errors = errors + 1;
        end
        if (sw_trickle_en !== 4'b0000) begin
            $display("[FAIL] Expected sw_trickle_en = 4'b0000, got %b", sw_trickle_en);
            errors = errors + 1;
        end
        if (sw_main_en !== 4'b0000) begin
            $display("[FAIL] Expected sw_main_en = 4'b0000, got %b", sw_main_en);
            errors = errors + 1;
        end
        if (pd_on !== 4'b0000) begin
            $display("[FAIL] Expected pd_on = 4'b0000, got %b", pd_on);
            errors = errors + 1;
        end
        mmio_read(8'h04, read_val);
        if (read_val !== 32'h0000_0000) begin
            $display("[FAIL] Expected PD_STATUS = 0, got 0x%08x", read_val);
            errors = errors + 1;
        end
        if (errors == 0) $display("[PASS] Test 1: Reset values verified.");

        $display("==================================================");
        $display("[TEST 2] Safe Power-Up with STAGGER=20 and PD_ORDER=0x76543102");
        $display("==================================================");
        // Configure STAGGER=20, PD_ORDER=0x76543102
        mmio_write(8'h10, 32'd20);
        mmio_write(8'h14, 32'h7654_3102);

        // Clear recorded edge timestamps
        for (k = 0; k < G; k = k + 1) begin
            tr_rise_cycle[k] = -1;
            tr_ack_cycle[k]  = -1;
            mn_rise_cycle[k] = -1;
            rst_rel_cycle[k] = -1;
            iso_rel_cycle[k] = -1;
        end

        // Request all 4 groups ON
        mmio_write(8'h00, 32'h0F);

        // Wait until all groups reach ON (pd_on == 4'b1111)
        while (pd_on !== 4'b1111) @(posedge clk);
        #(CLK_PERIOD * 5);

        // Verify order of trickle_en rising edges: group 2 first, then 0, then 1, then 3
        $display("  trickle_en rising cycles: Grp0=%0d, Grp1=%0d, Grp2=%0d, Grp3=%0d",
                 tr_rise_cycle[0], tr_rise_cycle[1], tr_rise_cycle[2], tr_rise_cycle[3]);

        if (!(tr_rise_cycle[2] < tr_rise_cycle[0] &&
              tr_rise_cycle[0] < tr_rise_cycle[1] &&
              tr_rise_cycle[1] < tr_rise_cycle[3])) begin
            $display("[FAIL] Incorrect trickle_en activation order! Expected 2 -> 0 -> 1 -> 3.");
            errors = errors + 1;
        end else begin
            $display("[PASS] Order verified: Grp2 -> Grp0 -> Grp1 -> Grp3.");
        end

        // Verify spacing between successive rising edges >= 20 cycles
        if ((tr_rise_cycle[0] - tr_rise_cycle[2]) < 20) begin
            $display("[FAIL] Spacing between Grp2 and Grp0 is %0d (< 20)", tr_rise_cycle[0] - tr_rise_cycle[2]);
            errors = errors + 1;
        end
        if ((tr_rise_cycle[1] - tr_rise_cycle[0]) < 20) begin
            $display("[FAIL] Spacing between Grp0 and Grp1 is %0d (< 20)", tr_rise_cycle[1] - tr_rise_cycle[0]);
            errors = errors + 1;
        end
        if ((tr_rise_cycle[3] - tr_rise_cycle[1]) < 20) begin
            $display("[FAIL] Spacing between Grp1 and Grp3 is %0d (< 20)", tr_rise_cycle[3] - tr_rise_cycle[1]);
            errors = errors + 1;
        end

        // Verify for each group:
        // (a) trickle precedes main by >= T_TRICKLE (16) cycles
        // (b) main_en rises only after trickle_ack
        // (c) iso released after pd_rst_n release
        for (k = 0; k < G; k = k + 1) begin
            if ((mn_rise_cycle[k] - tr_rise_cycle[k]) < 16) begin
                $display("[FAIL] Grp %0d: trickle to main duration %0d (< 16)",
                         k, mn_rise_cycle[k] - tr_rise_cycle[k]);
                errors = errors + 1;
            end
            if (mn_rise_cycle[k] <= tr_ack_cycle[k]) begin
                $display("[FAIL] Grp %0d: main_en (%0d) rose before or at trickle_ack (%0d)",
                         k, mn_rise_cycle[k], tr_ack_cycle[k]);
                errors = errors + 1;
            end
            if (iso_rel_cycle[k] <= rst_rel_cycle[k]) begin
                $display("[FAIL] Grp %0d: iso released (%0d) before or at pd_rst_n release (%0d)",
                         k, iso_rel_cycle[k], rst_rel_cycle[k]);
                errors = errors + 1;
            end
        end

        mmio_read(8'h04, read_val);
        // PD_STATUS: ON=0x0F, trans=0x00, eff_req=0x0F -> 0x000F000F
        if (read_val !== 32'h000F_000F) begin
            $display("[FAIL] PD_STATUS expected 0x000F000F, got 0x%08x", read_val);
            errors = errors + 1;
        end
        if (errors == 0) $display("[PASS] Test 2: Safe power-up sequence verified.");

        $display("==================================================");
        $display("[TEST 3] Power-Down of One Group (Grp 1)");
        $display("==================================================");
        // Clear power-down tracking
        iso_assert_cycle[1] = -1;
        rst_assert_cycle[1] = -1;
        sw_off_cycle[1]     = -1;

        // Turn off group 1: PD_REQ = 4'b1101 (0x0D)
        mmio_write(8'h00, 32'h0D);

        // Wait until Grp 1 is fully OFF: sw_trickle_en[1]==0, sw_main_en[1]==0
        while (sw_trickle_en[1] !== 1'b0 || sw_main_en[1] !== 1'b0) @(posedge clk);
        #(CLK_PERIOD * 5);

        $display("  Grp 1 power-down timing: iso_assert=%0d, rst_assert=%0d, sw_off=%0d",
                 iso_assert_cycle[1], rst_assert_cycle[1], sw_off_cycle[1]);

        // Check ISO -> rst -> switch off ordering
        if (!(iso_assert_cycle[1] < rst_assert_cycle[1] &&
              rst_assert_cycle[1] < sw_off_cycle[1])) begin
            $display("[FAIL] Incorrect power-down ordering! Expected ISO -> rst -> switch off.");
            errors = errors + 1;
        end else begin
            $display("[PASS] Power-down ordering verified (ISO -> rst -> switch off).");
        end

        if (pd_on !== 4'b1101) begin
            $display("[FAIL] Expected pd_on = 4'b1101, got %b", pd_on);
            errors = errors + 1;
        end
        if (errors == 0) $display("[PASS] Test 3: Power-down of Grp 1 verified.");

        $display("==================================================");
        $display("[TEST 4] UNSAFE_MODE=1 Fast Power-Up");
        $display("==================================================");
        // Power down all groups first
        mmio_write(8'h00, 32'h00);
        while (sw_trickle_en !== 4'b0000 || sw_main_en !== 4'b0000) @(posedge clk);
        #(CLK_PERIOD * 5);

        // Enable UNSAFE_MODE
        mmio_write(8'h18, 32'd1);

        for (k = 0; k < G; k = k + 1) begin
            tr_rise_cycle[k] = -1;
            mn_rise_cycle[k] = -1;
        end

        // Request all 4 groups
        mmio_write(8'h00, 32'h0F);

        // Wait until all groups are ON
        while (pd_on !== 4'b1111) @(posedge clk);
        #(CLK_PERIOD * 5);

        // Check that trickle_en and main_en rose in the SAME cycle for each group
        for (k = 0; k < G; k = k + 1) begin
            $display("  Grp %0d: tr_rise=%0d, mn_rise=%0d", k, tr_rise_cycle[k], mn_rise_cycle[k]);
            if (tr_rise_cycle[k] !== mn_rise_cycle[k]) begin
                $display("[FAIL] Grp %0d: trickle_en (%0d) and main_en (%0d) not in same cycle in UNSAFE_MODE!",
                         k, tr_rise_cycle[k], mn_rise_cycle[k]);
                errors = errors + 1;
            end
        end

        // Check that all groups rose in the same cycle
        if (!(tr_rise_cycle[0] == tr_rise_cycle[1] &&
              tr_rise_cycle[1] == tr_rise_cycle[2] &&
              tr_rise_cycle[2] == tr_rise_cycle[3])) begin
            $display("[FAIL] Groups did not activate in the same cycle in UNSAFE_MODE!");
            errors = errors + 1;
        end else begin
            $display("[PASS] All groups received trickle_en and main_en in the same cycle!");
        end

        // Disable UNSAFE_MODE
        mmio_write(8'h18, 32'd0);
        if (errors == 0) $display("[PASS] Test 4: UNSAFE_MODE verified.");

        $display("==================================================");
        $display("[TEST 5] HW Direct Active Override (hw_direct_active=1)");
        $display("==================================================");
        // MMIO PD_REQ is 4'hF currently.
        // hw_direct_active=1, hw_pd_req=8'h05 (groups 0, 2 ON; groups 1, 3 OFF)
        hw_pd_req = 8'h05;
        hw_direct_active = 1'b1;

        // Wait until groups 1 and 3 are OFF and groups 0 and 2 are ON
        while (pd_on !== 4'b0101) @(posedge clk);
        #(CLK_PERIOD * 5);

        mmio_read(8'h04, read_val);
        // Effective request should be 8'h05 (bits 23:16)
        if (read_val[23:16] !== 8'h05) begin
            $display("[FAIL] PD_STATUS effective request expected 0x05, got 0x%02x", read_val[23:16]);
            errors = errors + 1;
        end
        if (pd_on !== 4'b0101) begin
            $display("[FAIL] pd_on expected 4'b0101, got %b", pd_on);
            errors = errors + 1;
        end

        // Switch hw_pd_req to 8'h0A (groups 1, 3 ON; groups 0, 2 OFF)
        hw_pd_req = 8'h0A;
        while (pd_on !== 4'b1010) @(posedge clk);
        #(CLK_PERIOD * 5);

        mmio_read(8'h04, read_val);
        if (read_val[23:16] !== 8'h0A) begin
            $display("[FAIL] PD_STATUS effective request expected 0x0A, got 0x%02x", read_val[23:16]);
            errors = errors + 1;
        end
        if (pd_on !== 4'b1010) begin
            $display("[FAIL] pd_on expected 4'b1010, got %b", pd_on);
            errors = errors + 1;
        end

        // Disable hw_direct_active -> reverts to MMIO PD_REQ (4'hF)
        hw_direct_active = 1'b0;
        while (pd_on !== 4'b1111) @(posedge clk);
        #(CLK_PERIOD * 5);

        mmio_read(8'h04, read_val);
        if (read_val[23:16] !== 8'h0F) begin
            $display("[FAIL] PD_STATUS effective request expected 0x0F after hw_direct disabled, got 0x%02x", read_val[23:16]);
            errors = errors + 1;
        end
        if (errors == 0) $display("[PASS] Test 5: hw_direct_active override verified.");

        $display("==================================================");
        $display("[TEST 6] MMIO Readback of All Registers");
        $display("==================================================");
        // PD_REQ (0x00)
        mmio_write(8'h00, 32'h0A);
        mmio_read(8'h00, read_val);
        if (read_val !== 32'h0000_000A) begin
            $display("[FAIL] PD_REQ readback mismatch: expected 0x0A, got 0x%08x", read_val);
            errors = errors + 1;
        end

        // T_TRICKLE (0x08)
        mmio_write(8'h08, 32'h1234);
        mmio_read(8'h08, read_val);
        if (read_val !== 32'h0000_1234) begin
            $display("[FAIL] T_TRICKLE readback mismatch: expected 0x1234, got 0x%08x", read_val);
            errors = errors + 1;
        end

        // T_MAIN (0x0C)
        mmio_write(8'h0C, 32'h5678);
        mmio_read(8'h0C, read_val);
        if (read_val !== 32'h0000_5678) begin
            $display("[FAIL] T_MAIN readback mismatch: expected 0x5678, got 0x%08x", read_val);
            errors = errors + 1;
        end

        // STAGGER (0x10)
        mmio_write(8'h10, 32'h00AA);
        mmio_read(8'h10, read_val);
        if (read_val !== 32'h0000_00AA) begin
            $display("[FAIL] STAGGER readback mismatch: expected 0x00AA, got 0x%08x", read_val);
            errors = errors + 1;
        end

        // PD_ORDER (0x14)
        mmio_write(8'h14, 32'h1357_2468);
        mmio_read(8'h14, read_val);
        if (read_val !== 32'h1357_2468) begin
            $display("[FAIL] PD_ORDER readback mismatch: expected 0x13572468, got 0x%08x", read_val);
            errors = errors + 1;
        end

        // UNSAFE_MODE (0x18)
        mmio_write(8'h18, 32'h01);
        mmio_read(8'h18, read_val);
        if (read_val !== 32'h0000_0001) begin
            $display("[FAIL] UNSAFE_MODE readback mismatch: expected 1, got 0x%08x", read_val);
            errors = errors + 1;
        end
        mmio_write(8'h18, 32'h00);
        mmio_read(8'h18, read_val);
        if (read_val !== 32'h0000_0000) begin
            $display("[FAIL] UNSAFE_MODE readback mismatch: expected 0, got 0x%08x", read_val);
            errors = errors + 1;
        end

        // Unmapped address (0x20)
        mmio_read(8'h20, read_val);
        if (read_val !== 32'h0000_0000) begin
            $display("[FAIL] Unmapped register read expected 0, got 0x%08x", read_val);
            errors = errors + 1;
        end

        if (errors == 0) $display("[PASS] Test 6: All register readbacks verified.");

        $display("==================================================");
        if (errors == 0) begin
            $display("TEST PASSED");
            $finish(0);
        end else begin
            $display("TEST FAILED (%0d errors)", errors);
            $finish(1);
        end
    end

endmodule
