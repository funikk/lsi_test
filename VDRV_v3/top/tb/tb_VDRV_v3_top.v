`timescale 1ns/1ps
`include "defines.vh"

module tb_VDRV_v3_top;

    parameter TILE_ROWS    = 2;
    parameter TILE_COLS    = 2;
    parameter EDGE_COL_EN  = 1;
    parameter MAC_ROWS     = 4;
    parameter MAC_COLS     = 4;
    parameter EM_BUS_WIDTH = 32;
    parameter EM_FANOUT    = 64;

    reg clk;
    reg rst_n;
    reg [3:0] scenario_sel;
    wire scenario_done;
    wire sig_ok;
    wire [7:0] sig_out;
    wire [1:0] marker;

    reg uart_rx;
    wire uart_tx;

    wire [TILE_ROWS-1:0] sw_trickle_en;
    wire [TILE_ROWS-1:0] sw_trickle_ack;
    wire [TILE_ROWS-1:0] sw_main_en;
    wire [TILE_ROWS-1:0] sw_main_ack;

    // Instantiate Top
    VDRV_v3_top #(
        .TILE_ROWS    (TILE_ROWS),
        .TILE_COLS    (TILE_COLS),
        .EDGE_COL_EN  (EDGE_COL_EN),
        .MAC_ROWS     (MAC_ROWS),
        .MAC_COLS     (MAC_COLS),
        .EM_BUS_WIDTH (EM_BUS_WIDTH),
        .EM_FANOUT    (EM_FANOUT)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .scenario_sel   (scenario_sel),
        .scenario_done  (scenario_done),
        .sig_ok         (sig_ok),
        .sig_out        (sig_out),
        .marker         (marker),
        .uart_rx        (uart_rx),
        .uart_tx        (uart_tx),
        .sw_trickle_en  (sw_trickle_en),
        .sw_trickle_ack (sw_trickle_ack),
        .sw_main_en     (sw_main_en),
        .sw_main_ack    (sw_main_ack)
    );

    // Instantiate Behavioral Power Switch Models for each row
    genvar g;
    generate
        for (g = 0; g < TILE_ROWS; g = g + 1) begin : gen_sw_models
            vdrv_pwr_switch_model #(.DELAY(8)) u_sw_trickle (
                .clk   (clk),
                .rst_n (rst_n),
                .en    (sw_trickle_en[g]),
                .ack   (sw_trickle_ack[g])
            );
            vdrv_pwr_switch_model #(.DELAY(8)) u_sw_main (
                .clk   (clk),
                .rst_n (rst_n),
                .en    (sw_main_en[g]),
                .ack   (sw_main_ack[g])
            );
        end
    endgenerate

    initial clk = 0;
    always #5 clk = ~clk; // 100MHz clock

    always @(posedge clk) begin
        if (dut.u_core.cpu_mmio_req && dut.u_core.mem_ready) begin
            if (|dut.u_core.mem_wstrb) begin
                $display("[MMIO WR] time=%0t addr=%h wdata=%h", $time, dut.u_core.mem_addr, dut.u_core.mem_wdata);
            end else begin
                $display("[MMIO RD] time=%0t addr=%h rdata=%h", $time, dut.u_core.mem_addr, dut.u_core.mem_rdata);
            end
        end
    end

    initial begin
        $dumpfile("tb_VDRV_v3_top.vcd");
        $dumpvars(0, tb_VDRV_v3_top);

        rst_n        = 0;
        scenario_sel = 4'd1; // Scenario 1: ALL_ON_SYNC
        uart_rx      = 1'b1;

        #100;
        rst_n = 1;
        $display("[TB] Reset released at time %0t. Waiting for Scenario 1 completion...", $time);

        // Wait until scenario_done is asserted by firmware
        wait(scenario_done == 1'b1);
        #50;

        $display("[TB] scenario_done asserted at time %0t!", $time);
        $display("[TB] Status: sig_ok=%b, sig_out=0x%02h, marker=%b", sig_ok, sig_out, marker);
        $display("[TB] Tile raw sig: [0]=%h, [1]=%h, [2]=%h, [3]=%h, [4]=%h, [5]=%h",
                 dut.u_core.gen_row[0].gen_col[0].u_tile.sig_out,
                 dut.u_core.gen_row[0].gen_col[1].u_tile.sig_out,
                 dut.u_core.gen_row[0].gen_col[2].u_tile.sig_out,
                 dut.u_core.gen_row[1].gen_col[0].u_tile.sig_out,
                 dut.u_core.gen_row[1].gen_col[1].u_tile.sig_out,
                 dut.u_core.gen_row[1].gen_col[2].u_tile.sig_out);
        $display("[TB] iso_en=%b, pd_rst_n=%b, pd_on=%b", dut.u_core.iso_en, dut.u_core.pd_rst_n, dut.u_core.pd_on);
        $display("[TB] cfg_bridge reg_sig_sel=%0d, sig_data_selected=%h, sig_xor_all=%h",
                 dut.u_core.u_cfg_bridge.reg_sig_sel,
                 dut.u_core.u_cfg_bridge.sig_data_selected,
                 dut.u_core.u_cfg_bridge.sig_xor_all);

        if (!sig_ok) begin
            $display("==================================================");
            $display("[FAIL] VDRV_v3_top signature check failed in Scenario 1!");
            $display("==================================================");
            $finish(1);
        end
        $display("[PASS] Scenario 1 verified successfully.");

        // Next: Test Scenario 11 (EM_STRESS)
        #100;
        rst_n = 0;
        scenario_sel = 4'd11; // Scenario 11: EM_STRESS
        #100;
        rst_n = 1;
        $display("[TB] Reset released. Waiting for Scenario 11 completion...");

        wait(scenario_done == 1'b1);
        #50;
        $display("[TB] scenario_done asserted for Scenario 11 at time %0t!", $time);
        $display("[TB] Status: sig_ok=%b, sig_out=0x%02h, marker=%b", sig_ok, sig_out, marker);

        if (sig_ok) begin
            $display("==================================================");
            $display("[PASS] VDRV_v3_top full system co-simulation verified (Scenarios 1 & 11)!");
            $display("==================================================");
            $finish(0);
        end else begin
            $display("==================================================");
            $display("[FAIL] VDRV_v3_top signature check failed in Scenario 11!");
            $display("==================================================");
            $finish(1);
        end
    end

    // Timeout watchdog
    initial begin
        #500_000; // 500 us timeout
        $display("[FAIL] Co-simulation timed out!");
        $finish(2);
    end

endmodule
