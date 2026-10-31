`timescale 1ns/1ps

module tb_load_dma_subsys;

    reg         clk;
    reg         rst_n;

    // Hardware-direct load control from load_sequencer
    reg         hw_load_mode_active;
    reg         hw_mac_load_en;
    reg         hw_crc_load_en;

    // MMIO Slave Interface
    reg         mmio_valid;
    reg  [3:0]  mmio_wstrb;
    reg  [31:0] mmio_addr;
    reg  [31:0] mmio_wdata;
    wire [31:0] mmio_rdata;
    wire        mmio_ready;

    // DMA Master Interface
    wire        dma_valid;
    wire [3:0]  dma_wstrb;
    wire [31:0] dma_addr;
    wire [31:0] dma_wdata;
    wire [31:0] dma_rdata;
    wire        dma_ready;

    // Simulated DMEM (1KB / 256 words)
    reg [31:0] dmem [0:255];

    // DUT Instantiation
    load_dma_subsys dut (
        .clk(clk),
        .rst_n(rst_n),
        .hw_load_mode_active(hw_load_mode_active),
        .hw_mac_load_en(hw_mac_load_en),
        .hw_crc_load_en(hw_crc_load_en),
        .mmio_valid(mmio_valid),
        .mmio_wstrb(mmio_wstrb),
        .mmio_addr(mmio_addr),
        .mmio_wdata(mmio_wdata),
        .mmio_rdata(mmio_rdata),
        .mmio_ready(mmio_ready),
        .dma_valid(dma_valid),
        .dma_wstrb(dma_wstrb),
        .dma_addr(dma_addr),
        .dma_wdata(dma_wdata),
        .dma_rdata(dma_rdata),
        .dma_ready(dma_ready)
    );

    // 100MHz clock generation (10ns period)
    always #5 clk = ~clk;

    // Simulated DMEM Memory Responder
    always @(posedge clk) begin
        if (dma_valid && (dma_wstrb != 4'b0000)) begin
            dmem[dma_addr[9:2]] <= dma_wdata;
        end
    end
    assign dma_rdata = dmem[dma_addr[9:2]];
    assign dma_ready = 1'b1;

    // Helper Tasks for MMIO
    task mmio_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            #1;
            mmio_valid = 1'b1;
            mmio_wstrb = 4'hF;
            mmio_addr  = addr;
            mmio_wdata = data;
            @(posedge clk);
            #1;
            while (!mmio_ready) begin
                @(posedge clk);
                #1;
            end
            mmio_valid = 1'b0;
            mmio_wstrb = 4'h0;
            #1;
        end
    endtask

    task mmio_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            #1;
            mmio_valid = 1'b1;
            mmio_wstrb = 4'h0;
            mmio_addr  = addr;
            @(posedge clk);
            #1;
            while (!mmio_ready) begin
                @(posedge clk);
                #1;
            end
            data       = mmio_rdata;
            mmio_valid = 1'b0;
            #1;
        end
    endtask

    // Test Variables
    reg [31:0]  rdata0, rdata1, rdata2, rdata3;
    reg [31:0]  status_val;
    reg [31:0]  ctrl_val;
    reg [127:0] mac_res;
    reg [127:0] crc_res;
    reg [127:0] xor_res;
    integer     k;

    initial begin
        $display("===============================================================");
        $display("[TB START] Verification of load_dma_subsys started");
        $display("===============================================================");

        clk                 = 0;
        rst_n               = 0;
        hw_load_mode_active = 0;
        hw_mac_load_en      = 0;
        hw_crc_load_en      = 0;
        mmio_valid          = 0;
        mmio_wstrb          = 4'h0;
        mmio_addr           = 32'b0;
        mmio_wdata          = 32'b0;

        for (k = 0; k < 256; k = k + 1) begin
            dmem[k] = 32'b0;
        end

        #25;
        rst_n = 1;
        #20;

        // -----------------------------------------------------------------
        // Test 1: Seed & Config MMIO programming and PRNG readout
        // -----------------------------------------------------------------
        $display("\n[TEST 1] Seed & Config MMIO programming and PRNG readout...");
        mmio_write(32'h8000_0020, 32'h1111_2222);
        mmio_write(32'h8000_0024, 32'h3333_4444);
        mmio_write(32'h8000_0028, 32'h5555_6666);
        mmio_write(32'h8000_002C, 32'h7777_8888);

        // Pulse SEED_LOAD in REG_CTRL (bit 2)
        mmio_write(32'h8000_0000, 32'h0000_0004);

        // Read back PRNG data registers (0x30 - 0x3C)
        mmio_read(32'h8000_0030, rdata0);
        mmio_read(32'h8000_0034, rdata1);
        mmio_read(32'h8000_0038, rdata2);
        mmio_read(32'h8000_003C, rdata3);

        if (rdata0 !== 32'h1111_2222 || rdata1 !== 32'h3333_4444 ||
            rdata2 !== 32'h5555_6666 || rdata3 !== 32'h7777_8888) begin
            $display("[FAIL] Test 1: PRNG seed load mismatch! Read {0x%08h, 0x%08h, 0x%08h, 0x%08h}",
                     rdata3, rdata2, rdata1, rdata0);
            $finish(1);
        end

        // Program Config Registers (0x10 - 0x1C)
        mmio_write(32'h8000_0010, 32'h04C1_1DB7);
        mmio_write(32'h8000_0014, 32'h1EDC_6F41);
        mmio_write(32'h8000_0018, 32'h8260_8EDB);
        mmio_write(32'h8000_001C, 32'hA833_98D3);

        mmio_read(32'h8000_0010, rdata0);
        mmio_read(32'h8000_0014, rdata1);
        mmio_read(32'h8000_0018, rdata2);
        mmio_read(32'h8000_001C, rdata3);

        if (rdata0 !== 32'h04C1_1DB7 || rdata1 !== 32'h1EDC_6F41 ||
            rdata2 !== 32'h8260_8EDB || rdata3 !== 32'hA833_98D3) begin
            $display("[FAIL] Test 1: Config readback mismatch!");
            $finish(1);
        end
        $display("[PASS] Test 1: Seed & Config programming and PRNG readout verified.");

        // -----------------------------------------------------------------
        // Test 2: DMA Mode (MAC, CRC, MAC+CRC XOR)
        // -----------------------------------------------------------------
        $display("\n[TEST 2] DMA Mode (MAC, CRC, MAC+CRC XOR)...");
        // Populate DMEM source block at 0x100 (words 64..67)
        dmem[32'h40] = 32'h1234_5678; // 0x100
        dmem[32'h41] = 32'h9ABC_DEF0; // 0x104
        dmem[32'h42] = 32'hA5A5_5A5A; // 0x108
        dmem[32'h43] = 32'h55AA_33CC; // 0x10C

        // 2A: Run DMA mode 2'b00 (MAC only)
        mmio_write(32'h8000_0040, 32'h0000_0100); // SRC
        mmio_write(32'h8000_0044, 32'h0000_0200); // DST (words 128..131)
        mmio_write(32'h8000_0048, 32'd1);         // LEN = 1 block
        mmio_write(32'h8000_0000, 32'h0000_0001); // DMA_START, DMA_MODE_SEL = 00

        status_val = 0;
        while (!status_val[1]) begin
            mmio_read(32'h8000_0004, status_val);
        end
        mac_res = {dmem[32'h83], dmem[32'h82], dmem[32'h81], dmem[32'h80]};
        $display("  DMA MAC Result: 0x%032h", mac_res);
        if (mac_res === 128'b0) begin
            $display("[FAIL] Test 2: MAC result is zero!");
            $finish(1);
        end

        // 2B: Run DMA mode 2'b01 (CRC only)
        mmio_write(32'h8000_0040, 32'h0000_0100); // SRC
        mmio_write(32'h8000_0044, 32'h0000_0210); // DST (words 132..135)
        mmio_write(32'h8000_0048, 32'd1);         // LEN = 1 block
        mmio_write(32'h8000_0000, 32'h0000_0011); // DMA_START, DMA_MODE_SEL = 01

        status_val = 0;
        while (!status_val[1]) begin
            mmio_read(32'h8000_0004, status_val);
        end
        crc_res = {dmem[32'h87], dmem[32'h86], dmem[32'h85], dmem[32'h84]};
        $display("  DMA CRC Result: 0x%032h", crc_res);
        if (crc_res === 128'b0 || crc_res === mac_res) begin
            $display("[FAIL] Test 2: CRC result is zero or matches MAC!");
            $finish(1);
        end

        // 2C: Run DMA mode 2'b10 (MAC + CRC XOR)
        mmio_write(32'h8000_0040, 32'h0000_0100); // SRC
        mmio_write(32'h8000_0044, 32'h0000_0220); // DST (words 136..139)
        mmio_write(32'h8000_0048, 32'd1);         // LEN = 1 block
        mmio_write(32'h8000_0000, 32'h0000_0021); // DMA_START, DMA_MODE_SEL = 10

        status_val = 0;
        while (!status_val[1]) begin
            mmio_read(32'h8000_0004, status_val);
        end
        xor_res = {dmem[32'h8B], dmem[32'h8A], dmem[32'h89], dmem[32'h88]};
        $display("  DMA XOR Result: 0x%032h", xor_res);
        if (xor_res !== (mac_res ^ crc_res)) begin
            $display("[FAIL] Test 2: XOR result (0x%032h) != mac_res ^ crc_res (0x%032h)", xor_res, mac_res ^ crc_res);
            $finish(1);
        end
        $display("[PASS] Test 2: DMA mode (MAC, CRC, MAC+CRC XOR) verified successfully.");

        // -----------------------------------------------------------------
        // Test 3: Software finite-block continuous load mode (REG_LEN = 3)
        // -----------------------------------------------------------------
        $display("\n[TEST 3] Software finite-block continuous load mode (REG_LEN = 3)...");

        // 3A: MAC only
        $display("  3A: SW MAC only (REG_LEN = 3)...");
        mmio_write(32'h8000_0048, 32'd3);         // LEN = 3
        mmio_write(32'h8000_0000, 32'h0000_0002); // SW_MAC_LOAD_EN = 1

        status_val = 0;
        while (!status_val[1]) begin
            mmio_read(32'h8000_0004, status_val);
        end
        mmio_read(32'h8000_0000, ctrl_val);
        if (ctrl_val[1] !== 1'b0) begin
            $display("[FAIL] Test 3A: SW_MAC_LOAD_EN not auto-cleared! ctrl = 0x%08h", ctrl_val);
            $finish(1);
        end
        $display("  [PASS] 3A: MAC only completed 3 blocks, auto-cleared.");

        // 3B: CRC only
        $display("  3B: SW CRC only (REG_LEN = 3)...");
        mmio_write(32'h8000_0048, 32'd3);         // LEN = 3
        mmio_write(32'h8000_0000, 32'h0000_0008); // SW_CRC_LOAD_EN = 1

        status_val = 0;
        while (!status_val[1]) begin
            mmio_read(32'h8000_0004, status_val);
        end
        mmio_read(32'h8000_0000, ctrl_val);
        if (ctrl_val[3] !== 1'b0) begin
            $display("[FAIL] Test 3B: SW_CRC_LOAD_EN not auto-cleared! ctrl = 0x%08h", ctrl_val);
            $finish(1);
        end
        $display("  [PASS] 3B: CRC only completed 3 blocks, auto-cleared.");

        // 3C: MAC + CRC simultaneously
        $display("  3C: SW MAC + CRC simultaneously (REG_LEN = 3)...");
        mmio_write(32'h8000_0048, 32'd3);         // LEN = 3
        mmio_write(32'h8000_0000, 32'h0000_000A); // SW_MAC_LOAD_EN = 1, SW_CRC_LOAD_EN = 1

        status_val = 0;
        while (!status_val[1]) begin
            mmio_read(32'h8000_0004, status_val);
        end
        mmio_read(32'h8000_0000, ctrl_val);
        if (ctrl_val[1] !== 1'b0 || ctrl_val[3] !== 1'b0) begin
            $display("[FAIL] Test 3C: SW enables not auto-cleared! ctrl = 0x%08h", ctrl_val);
            $finish(1);
        end
        $display("  [PASS] 3C: Simultaneous MAC + CRC completed 3 blocks, both auto-cleared.");

        // 3D: SW infinite load mode with dynamic switching (REG_LEN = 0)
        $display("  3D: SW infinite load dynamic switching (REG_LEN = 0)...");
        mmio_write(32'h8000_0048, 32'd0); // LEN = 0 (infinite)

        // Switch to MAC only
        mmio_write(32'h8000_0000, 32'h0000_0002); // SW_MAC_LOAD_EN = 1
        repeat (25) @(posedge clk);
        mmio_read(32'h8000_0004, status_val);
        $display("    Infinite MAC status: 0x%08h (mac_busy=%b, crc_busy=%b)", status_val, status_val[2], status_val[3]);
        if (status_val[2] !== 1'b1) begin
            $display("[FAIL] Test 3D: MAC core not busy in infinite MAC mode!");
            $finish(1);
        end

        // Dynamic switch to CRC only without clearing REG_CTRL first
        mmio_write(32'h8000_0000, 32'h0000_0008); // SW_CRC_LOAD_EN = 1, SW_MAC_LOAD_EN = 0
        repeat (25) @(posedge clk);
        mmio_read(32'h8000_0004, status_val);
        $display("    Infinite CRC status: 0x%08h (mac_busy=%b, crc_busy=%b)", status_val, status_val[2], status_val[3]);
        if (status_val[3] !== 1'b1) begin
            $display("[FAIL] Test 3D: CRC core not busy after dynamic switch!");
            $finish(1);
        end

        // Dynamic switch to MAC + CRC both
        mmio_write(32'h8000_0000, 32'h0000_000A); // SW_MAC_LOAD_EN = 1, SW_CRC_LOAD_EN = 1
        repeat (25) @(posedge clk);
        mmio_read(32'h8000_0004, status_val);
        $display("    Infinite MAC+CRC status: 0x%08h (mac_busy=%b, crc_busy=%b)", status_val, status_val[2], status_val[3]);
        if (status_val[2] !== 1'b1 || status_val[3] !== 1'b1) begin
            $display("[FAIL] Test 3D: Both cores not busy in infinite MAC+CRC mode!");
            $finish(1);
        end

        // Stop continuous load
        mmio_write(32'h8000_0000, 32'h0000_0000);
        repeat (20) @(posedge clk);
        mmio_read(32'h8000_0004, status_val);
        if (status_val[2] !== 1'b0 || status_val[3] !== 1'b0) begin
            $display("[FAIL] Test 3D: Cores still busy after stopping infinite mode!");
            $finish(1);
        end
        $display("  [PASS] 3D: Dynamic switching in infinite load mode verified successfully.");
        $display("[PASS] Test 3: Software continuous/finite-block load mode verified successfully.");

        // -----------------------------------------------------------------
        // Test 4: Hardware-direct mode dynamic stepping
        // -----------------------------------------------------------------
        $display("\n[TEST 4] Hardware-direct mode dynamic stepping...");
        @(posedge clk); #1;
        hw_load_mode_active = 1'b1;

        // Step 0: MAC only
        $display("  Step 0: HW MAC only...");
        hw_mac_load_en = 1'b1;
        hw_crc_load_en = 1'b0;
        repeat (25) @(posedge clk);
        mmio_read(32'h8000_0004, status_val);
        $display("  Status in Step 0: 0x%08h", status_val);

        // Step 1: CRC only
        $display("  Step 1: HW CRC only...");
        hw_mac_load_en = 1'b0;
        hw_crc_load_en = 1'b1;
        repeat (25) @(posedge clk);
        mmio_read(32'h8000_0004, status_val);
        $display("  Status in Step 1: 0x%08h", status_val);

        // Step 2: MAC + CRC both
        $display("  Step 2: HW MAC + CRC...");
        hw_mac_load_en = 1'b1;
        hw_crc_load_en = 1'b1;
        repeat (25) @(posedge clk);
        mmio_read(32'h8000_0004, status_val);
        $display("  Status in Step 2: 0x%08h", status_val);

        // Step 3: IDLE
        $display("  Step 3: HW IDLE...");
        hw_mac_load_en = 1'b0;
        hw_crc_load_en = 1'b0;
        repeat (15) @(posedge clk);
        hw_load_mode_active = 1'b0;
        repeat (5) @(posedge clk);
        mmio_read(32'h8000_0004, status_val);
        $display("  Status after return to IDLE: 0x%08h", status_val);
        if (status_val[0] !== 1'b0 || status_val[2] !== 1'b0 || status_val[3] !== 1'b0) begin
            $display("[FAIL] Test 4: Cores not idle! status = 0x%08h", status_val);
            $finish(1);
        end
        $display("[PASS] Test 4: Hardware-direct mode dynamic stepping verified successfully.");

        $display("\n===============================================================");
        $display("[TB SUCCESS] ALL load_dma_subsys UNIT TESTS PASSED");
        $display("===============================================================\n");
        $finish(0);
    end

endmodule
