`timescale 1ns/1ps
`include "defines.vh"

module tb_VDRV_v1a_top;

    reg clk;
    reg rst_n;

    reg in_valid;
    reg [`DATA_WIDTH-1:0] in_data;
    wire out_valid;
    wire [`DATA_WIDTH-1:0] out_data;

    reg uart_rx;
    wire uart_tx;

    wire mac_load_mode_en;
    wire crc_load_mode_en;
    wire [2:0] cpu_load_state;

    VDRV_v1a_top u_top (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(out_valid),
        .out_data(out_data),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .mac_load_mode_en(mac_load_mode_en),
        .crc_load_mode_en(crc_load_mode_en),
        .cpu_load_state(cpu_load_state)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    localparam CLK_PER_BIT = 868;
    localparam BIT_PERIOD = CLK_PER_BIT * 10; // 8680 ns per bit

    task send_byte;
        input [7:0] data;
        integer i;
        begin
            uart_rx = 1'b0; // start bit
            #(BIT_PERIOD);
            for (i=0; i<8; i=i+1) begin
                uart_rx = data[i];
                #(BIT_PERIOD);
            end
            uart_rx = 1'b1; // stop bit
            #(BIT_PERIOD);
        end
    endtask

`ifdef SDF_FILE
    initial begin
        $display("[TB] Annotating SDF file: %s to instance tb_VDRV_v1a_top.u_top.u_core", `SDF_FILE);
        $sdf_annotate(`SDF_FILE, u_top.u_core);
    end
`endif

    initial begin
`ifdef DUMP_FSDB
        $fsdbDumpfile("tb_VDRV_v1a_top.fsdb");
        $fsdbDumpvars(0, tb_VDRV_v1a_top, "+all");
        $fsdbDumpMDA();
`elsif DUMP_VCD
        $dumpfile("tb_VDRV_v1a_top.vcd");
        $dumpvars(0, tb_VDRV_v1a_top);
`elsif NO_DUMP
        // Waveform dump disabled
`else
        $dumpfile("tb_VDRV_v1a_top.vcd");
        $dumpvars(0, tb_VDRV_v1a_top);
`endif

        rst_n = 0;
        in_valid = 0;
        in_data = 0;
        uart_rx = 1'b1;

        #100;
        rst_n = 1;

        // 1. Wait for firmware self-test completion (mem[63] == 0xDEADBEEF)
        $display("[TB] Waiting for firmware self-test completion (DMEM[63] == 0xDEADBEEF)...");
        while (u_top.u_dmem.mem[63] !== 32'hDEADBEEF) begin
            @(posedge clk);
        end
        $display("[TB] Firmware self-test completed! Magic marker detected: 0x%08x", u_top.u_dmem.mem[63]);

        // Verify MAC DMA output at mem[8..11] and CRC DMA output at mem[12..15]
        $display("[TB] MAC DMA Output (mem[8..11]): 0x%08x 0x%08x 0x%08x 0x%08x",
            u_top.u_dmem.mem[8], u_top.u_dmem.mem[9], u_top.u_dmem.mem[10], u_top.u_dmem.mem[11]);
        $display("[TB] CRC DMA Output (mem[12..15]): 0x%08x 0x%08x 0x%08x 0x%08x",
            u_top.u_dmem.mem[12], u_top.u_dmem.mem[13], u_top.u_dmem.mem[14], u_top.u_dmem.mem[15]);

        if (u_top.u_dmem.mem[8]  == 32'd0 || u_top.u_dmem.mem[9]  == 32'd0 ||
            u_top.u_dmem.mem[10] == 32'd0 || u_top.u_dmem.mem[11] == 32'd0) begin
            $display("[FAIL] MAC DMA output at mem[8..11] is zero!");
            $finish(1);
        end

        if (u_top.u_dmem.mem[12] == 32'd0 || u_top.u_dmem.mem[13] == 32'd0 ||
            u_top.u_dmem.mem[14] == 32'd0 || u_top.u_dmem.mem[15] == 32'd0) begin
            $display("[FAIL] CRC DMA output at mem[12..15] is zero!");
            $finish(1);
        end

        if ((u_top.u_dmem.mem[8]  == u_top.u_dmem.mem[12]) &&
            (u_top.u_dmem.mem[9]  == u_top.u_dmem.mem[13]) &&
            (u_top.u_dmem.mem[10] == u_top.u_dmem.mem[14]) &&
            (u_top.u_dmem.mem[11] == u_top.u_dmem.mem[15])) begin
            $display("[FAIL] MAC DMA output and CRC DMA output are identical!");
            $finish(1);
        end
        $display("[PASS] MAC and CRC DMA outputs are non-zero and distinct.");

        // 2. Program 4 steps into load_sequencer via UART send_byte
        // Step 0: state 3'b001 (MAC_ONLY, data1 = 8'h10), duration 2
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'h01); // CMD_SET_STEP
        send_byte(8'h10); // data1: state=3'b001, id=4'h0
        send_byte(8'h00); // dur_H
        send_byte(8'h02); // dur_L = 2
        #(BIT_PERIOD * 2);

        // Step 1: state 3'b010 (CRC_ONLY, data1 = 8'h21), duration 2
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'h01); // CMD_SET_STEP
        send_byte(8'h21); // data1: state=3'b010, id=4'h1
        send_byte(8'h00); // dur_H
        send_byte(8'h02); // dur_L = 2
        #(BIT_PERIOD * 2);

        // Step 2: state 3'b011 (MAC+CRC, data1 = 8'h32), duration 2
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'h01); // CMD_SET_STEP
        send_byte(8'h32); // data1: state=3'b011, id=4'h2
        send_byte(8'h00); // dur_H
        send_byte(8'h02); // dur_L = 2
        #(BIT_PERIOD * 2);

        // Step 3: state 3'b111 (ALL_FULL, data1 = 8'h73), duration 2
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'h01); // CMD_SET_STEP
        send_byte(8'h73); // data1: state=3'b111, id=4'h3
        send_byte(8'h00); // dur_H
        send_byte(8'h02); // dur_L = 2
        #(BIT_PERIOD * 2);

        // 3. Send CMD_START_SEQ (0xAA 0x55 0x02)
        $display("[TB] Sending CMD_START_SEQ to load_sequencer...");
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'h02);

        // 4. Verify transitions through all expected states:
        $display("[TB] Monitoring state transitions...");

        // Wait for Step 0 (3'b001)
        while (cpu_load_state !== 3'b001) @(posedge clk);
        if (mac_load_mode_en !== 1'b1 || crc_load_mode_en !== 1'b0) begin
            $display("[FAIL] Step 0 signals mismatch: mac=%b, crc=%b, state=%b", mac_load_mode_en, crc_load_mode_en, cpu_load_state);
            $finish(1);
        end
        $display("[PASS] Step 0 verified: cpu_load_state=3'b001, mac_load_mode_en=%b, crc_load_mode_en=%b", mac_load_mode_en, crc_load_mode_en);

        // Wait for Step 1 (3'b010)
        while (cpu_load_state !== 3'b010) @(posedge clk);
        if (mac_load_mode_en !== 1'b0 || crc_load_mode_en !== 1'b1) begin
            $display("[FAIL] Step 1 signals mismatch: mac=%b, crc=%b, state=%b", mac_load_mode_en, crc_load_mode_en, cpu_load_state);
            $finish(1);
        end
        $display("[PASS] Step 1 verified: cpu_load_state=3'b010, mac_load_mode_en=%b, crc_load_mode_en=%b", mac_load_mode_en, crc_load_mode_en);

        // Wait for Step 2 (3'b011)
        while (cpu_load_state !== 3'b011) @(posedge clk);
        if (mac_load_mode_en !== 1'b1 || crc_load_mode_en !== 1'b1) begin
            $display("[FAIL] Step 2 signals mismatch: mac=%b, crc=%b, state=%b", mac_load_mode_en, crc_load_mode_en, cpu_load_state);
            $finish(1);
        end
        $display("[PASS] Step 2 verified: cpu_load_state=3'b011, mac_load_mode_en=%b, crc_load_mode_en=%b", mac_load_mode_en, crc_load_mode_en);

        // Wait for Step 3 (3'b111)
        while (cpu_load_state !== 3'b111) @(posedge clk);
        if (mac_load_mode_en !== 1'b1 || crc_load_mode_en !== 1'b1) begin
            $display("[FAIL] Step 3 signals mismatch: mac=%b, crc=%b, state=%b", mac_load_mode_en, crc_load_mode_en, cpu_load_state);
            $finish(1);
        end
        $display("[PASS] Step 3 verified: cpu_load_state=3'b111, mac_load_mode_en=%b, crc_load_mode_en=%b", mac_load_mode_en, crc_load_mode_en);

        #1000;
        $display("[PASS] ALL SYSTEM-LEVEL VERIFICATION CHECKS PASSED SUCCESSFULLY!");
        $finish(0);
    end

    // Safety timeout
    initial begin
        #50_000_000; // 50ms simulation time
        $display("[FAIL] Simulation timeout reached!");
        $finish(1);
    end

endmodule
