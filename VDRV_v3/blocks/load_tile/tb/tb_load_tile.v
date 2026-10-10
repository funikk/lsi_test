`timescale 1ns/1ps
// Self-checking unit testbench for load_tile.
// Tiles: T00/T01 standard, T02 low-activity, T03 SRAM (all share the cfg bus).
module tb_load_tile;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;

    reg        cfg_valid = 0;
    reg [7:0]  cfg_tile_id = 0;
    reg [4:0]  cfg_addr = 0;
    reg [31:0] cfg_wdata = 0;
    reg        pg_sync = 0;
    reg [1:0]  profile_id = 0;

    wire [31:0] sig0, sig1, sig2, sig3;
    wire la0, la1, la2, la3;

    load_tile #(.TILE_TYPE(0), .TILE_ID(8'h00)) u_t0 (
        .clk(clk), .rst_n(rst_n), .cfg_valid(cfg_valid), .cfg_tile_id(cfg_tile_id),
        .cfg_addr(cfg_addr), .cfg_wdata(cfg_wdata), .pg_sync(pg_sync), .profile_id(profile_id),
        .sig_out(sig0), .load_active(la0));
    load_tile #(.TILE_TYPE(0), .TILE_ID(8'h01)) u_t1 (
        .clk(clk), .rst_n(rst_n), .cfg_valid(cfg_valid), .cfg_tile_id(cfg_tile_id),
        .cfg_addr(cfg_addr), .cfg_wdata(cfg_wdata), .pg_sync(pg_sync), .profile_id(profile_id),
        .sig_out(sig1), .load_active(la1));
    load_tile #(.TILE_TYPE(1), .TILE_ID(8'h02), .LOWACT_FFS(256)) u_t2 (
        .clk(clk), .rst_n(rst_n), .cfg_valid(cfg_valid), .cfg_tile_id(cfg_tile_id),
        .cfg_addr(cfg_addr), .cfg_wdata(cfg_wdata), .pg_sync(pg_sync), .profile_id(profile_id),
        .sig_out(sig2), .load_active(la2));
    load_tile #(.TILE_TYPE(2), .TILE_ID(8'h13)) u_t3 (
        .clk(clk), .rst_n(rst_n), .cfg_valid(cfg_valid), .cfg_tile_id(cfg_tile_id),
        .cfg_addr(cfg_addr), .cfg_wdata(cfg_wdata), .pg_sync(pg_sync), .profile_id(profile_id),
        .sig_out(sig3), .load_active(la3));

    integer errors = 0;

    task check(input cond, input [8*64-1:0] msg);
        begin
            if (!cond) begin
                errors = errors + 1;
                $display("[FAIL] %0s (t=%0t)", msg, $time);
            end else begin
                $display("[ OK ] %0s", msg);
            end
        end
    endtask

    task cfg_wr(input [7:0] id, input [4:0] addr, input [31:0] data);
        begin
            @(negedge clk);
            cfg_valid = 1; cfg_tile_id = id; cfg_addr = addr; cfg_wdata = data;
            @(negedge clk);
            cfg_valid = 0;
        end
    endtask

    // PG_CTRL encoding helper
    function [31:0] pgctrl(input [1:0] mode, input [4:0] act, input gate);
        pgctrl = {19'h0, gate, 3'h0, act, 2'h0, mode};
    endfunction

    task sync_pulse;
        begin
            @(negedge clk); pg_sync = 1; @(negedge clk); pg_sync = 0;
        end
    endtask

    // Gated-clock edge counter for T00
    integer gclk_edges = 0;
    always @(posedge u_t0.gclk) gclk_edges = gclk_edges + 1;

    integer i, ones0, ones1, first0, first1;
    reg [31:0] s_a, s_b;
    reg [127:0] d_a, d_b, d_diff;

    initial begin
        $dumpfile("tb_load_tile.vcd");
        $dumpvars(0, tb_load_tile);
        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (10) @(negedge clk);

        // 1. Reset state: all profiles OFF
        check(la0 == 0 && la1 == 0 && la2 == 0 && la3 == 0, "reset: load_active = 0");
        check(sig0 == 0 && sig1 == 0, "reset: signatures = 0");

        // 2. Broadcast profile0 = always ON, ACT 16, no gating
        cfg_wr(8'hFF, 5'h00, pgctrl(2'd1, 5'd16, 1'b0));
        repeat (6) @(negedge clk);
        check(la0 && la1 && la2 && la3, "profile0 ALWAYS_ON: all tiles active");
        repeat (200) @(negedge clk);
        check(sig0 == sig1, "identical std tiles -> identical signature");
        check(sig0 != 0, "std signature non-zero");
        check(^sig2 !== 1'bx && ^sig3 !== 1'bx, "lowact/sram signatures are not X");
        check(sig3 != 0, "sram signature non-zero");

        // 3. Turn off and clear signatures (broadcast)
        cfg_wr(8'hFF, 5'h00, pgctrl(2'd0, 5'd16, 1'b0));
        cfg_wr(8'hFF, 5'h10, 32'h1);
        repeat (6) @(negedge clk);
        check(sig0 == 0 && sig1 == 0 && sig2 == 0 && sig3 == 0, "SIG_CLEAR clears all signatures");

        // 4. Periodic pattern, profile1: PERIOD 10, DUTY 3, PHASE 0 (T00) / 5 (T01)
        cfg_wr(8'hFF, 5'h04, pgctrl(2'd2, 5'd16, 1'b0));
        cfg_wr(8'hFF, 5'h05, {16'd3, 16'd10});
        cfg_wr(8'h00, 5'h06, 32'd0);
        cfg_wr(8'h01, 5'h06, 32'd5);
        @(negedge clk); profile_id = 2'd1;
        repeat (4) @(negedge clk);
        sync_pulse;
        repeat (20) @(negedge clk);
        ones0 = 0; ones1 = 0; first0 = -1; first1 = -1;
        for (i = 0; i < 100; i = i + 1) begin
            @(negedge clk);
            ones0 = ones0 + la0; ones1 = ones1 + la1;
            if (la0 && first0 < 0 && i > 0) first0 = i;
            if (la1 && first1 < 0 && i > 0) first1 = i;
        end
        check(ones0 == 30 && ones1 == 30, "periodic: duty 3/10 on both tiles");
        $display("       first rising index: T00=%0d T01=%0d", first0, first1);
        check(((first0 - first1 + 10) % 10) == 5, "periodic: phase offset of 5 cycles");

        // 5. Clock gating: profile2 = OFF with GATE_MODE=1 -> gclk stops
        cfg_wr(8'hFF, 5'h08, pgctrl(2'd0, 5'd16, 1'b1));
        @(negedge clk); profile_id = 2'd2;
        repeat (6) @(negedge clk);
        gclk_edges = 0; s_a = sig0;
        repeat (50) @(negedge clk);
        check(gclk_edges == 0, "GATE_MODE=1 & OFF: gated clock stopped");
        check(sig0 == s_a, "GATE_MODE=1 & OFF: signature frozen");
        // profile3 = OFF without gating -> gclk runs
        cfg_wr(8'hFF, 5'h0C, pgctrl(2'd0, 5'd16, 1'b0));
        @(negedge clk); profile_id = 2'd3;
        repeat (6) @(negedge clk);
        gclk_edges = 0;
        repeat (50) @(negedge clk);
        check(gclk_edges == 50, "GATE_MODE=0 & OFF: gated clock free-running");

        // 6. ACT_LEVEL: 0 -> data register static, 8 -> upper half of each 16-bit lane static
        cfg_wr(8'hFF, 5'h0C, pgctrl(2'd1, 5'd0, 1'b0));
        repeat (6) @(negedge clk);
        d_a = u_t0.g_std.u_core.d;
        repeat (20) @(negedge clk);
        d_b = u_t0.g_std.u_core.d;
        check(d_a == d_b, "ACT_LEVEL=0: data register static");
        cfg_wr(8'hFF, 5'h0C, pgctrl(2'd1, 5'd8, 1'b0));
        repeat (4) @(negedge clk);
        d_diff = 0;
        d_a = u_t0.g_std.u_core.d;
        for (i = 0; i < 50; i = i + 1) begin
            @(negedge clk);
            d_diff = d_diff | (d_a ^ u_t0.g_std.u_core.d);
            d_a = u_t0.g_std.u_core.d;
        end
        check((d_diff & {8{16'hFF00}}) == 0, "ACT_LEVEL=8: masked bits never toggle");
        check((d_diff & {8{16'h00FF}}) != 0, "ACT_LEVEL=8: active bits toggle");

        // 7. Column broadcast (0xF1) only hits T01; row broadcast (0x1F) only hits T13
        cfg_wr(8'hFF, 5'h0C, pgctrl(2'd0, 5'd0, 1'b0));
        repeat (4) @(negedge clk);
        cfg_wr(8'hF1, 5'h0C, pgctrl(2'd1, 5'd16, 1'b0));
        repeat (6) @(negedge clk);
        check(!la0 && la1 && !la2 && !la3, "column broadcast 0xF1 hits only tile 01");
        cfg_wr(8'h1F, 5'h0C, pgctrl(2'd1, 5'd16, 1'b0));
        repeat (6) @(negedge clk);
        check(!la0 && la1 && !la2 && la3, "row broadcast 0x1F hits only tile 13");

        // 8. SEED_MIX_ID: identical config but different seeds -> different signatures
        cfg_wr(8'hFF, 5'h0C, pgctrl(2'd0, 5'd16, 1'b0));
        cfg_wr(8'hFF, 5'h10, 32'h7);   // clear + seed load + mix id
        cfg_wr(8'hFF, 5'h0C, pgctrl(2'd1, 5'd16, 1'b0));
        repeat (100) @(negedge clk);
        check(sig0 != sig1, "SEED_MIX_ID: tiles diverge");
        cfg_wr(8'hFF, 5'h0C, pgctrl(2'd0, 5'd16, 1'b0));
        cfg_wr(8'hFF, 5'h11, 32'hCAFE_F00D);
        cfg_wr(8'hFF, 5'h10, 32'h3);   // clear + seed load, mix off
        cfg_wr(8'hFF, 5'h0C, pgctrl(2'd1, 5'd16, 1'b0));
        repeat (100) @(negedge clk);
        check(sig0 == sig1, "common seed reload: tiles identical again");

        // 9. Random burst mode produces partial activity
        cfg_wr(8'hFF, 5'h0C, pgctrl(2'd3, 5'd16, 1'b0));
        repeat (4) @(negedge clk);
        ones0 = 0;
        for (i = 0; i < 400; i = i + 1) begin
            @(negedge clk);
            ones0 = ones0 + la0;
        end
        $display("       random burst duty: %0d/400", ones0);
        check(ones0 > 120 && ones0 < 280, "random burst: ~50% duty");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED (%0d errors)", errors);
        $finish;
    end

    initial begin
        #2_000_000;
        $display("TEST FAILED (timeout)");
        $finish;
    end
endmodule
