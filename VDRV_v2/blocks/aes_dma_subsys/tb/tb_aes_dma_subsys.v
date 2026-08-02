`timescale 1ns / 1ps

module tb_aes_dma_subsys;

    reg clk;
    reg rst_n;
    reg hw_load_mode_active;
    reg hw_load_mode_en;
    reg aes_power_ready;
    reg aes_quiesce_req;
    reg pd_aes_on;
    reg pd_aes_reset_n;
    reg aes_isolate;
    wire aes_idle;

    // MMIO Slave
    reg mmio_valid;
    reg [3:0] mmio_wstrb;
    reg [31:0] mmio_addr;
    reg [31:0] mmio_wdata;
    wire [31:0] mmio_rdata;
    wire mmio_ready;

    // DMA Master
    wire dma_valid;
    wire [3:0] dma_wstrb;
    wire [31:0] dma_addr;
    wire [31:0] dma_wdata;
    reg [31:0] dma_rdata;
    reg dma_ready;

    // DUT Instance
    aes_dma_subsys u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .hw_load_mode_active(hw_load_mode_active),
        .hw_load_mode_en(hw_load_mode_en),
        .aes_power_ready(aes_power_ready),
        .aes_quiesce_req(aes_quiesce_req),
        .pd_aes_on(pd_aes_on),
        .pd_aes_reset_n(pd_aes_reset_n),
        .aes_isolate(aes_isolate),
        .aes_idle(aes_idle),
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

    always #5 clk = ~clk;

    // MMIO Read Task
    task mmio_read(input [31:0] addr, output [31:0] rdata);
        begin
            @(posedge clk);
            mmio_valid = 1'b1;
            mmio_wstrb = 4'b0000;
            mmio_addr  = addr;
            @(posedge clk);
            while (!mmio_ready) @(posedge clk);
            rdata = mmio_rdata;
            mmio_valid = 1'b0;
        end
    endtask

    // MMIO Write Task
    task mmio_write(input [31:0] addr, input [31:0] wdata);
        begin
            @(posedge clk);
            mmio_valid = 1'b1;
            mmio_wstrb = 4'b1111;
            mmio_addr  = addr;
            mmio_wdata = wdata;
            @(posedge clk);
            while (!mmio_ready) @(posedge clk);
            mmio_valid = 1'b0;
            mmio_wstrb = 4'b0000;
        end
    endtask

    reg [31:0] read_val;

    initial begin
        clk = 0;
        rst_n = 0;
        hw_load_mode_active = 0;
        hw_load_mode_en = 0;
        aes_power_ready = 1;
        aes_quiesce_req = 0;
        pd_aes_on = 0;
        pd_aes_reset_n = 0;
        aes_isolate = 0;
        mmio_valid = 0;
        mmio_wstrb = 0;
        mmio_addr = 0;
        mmio_wdata = 0;
        dma_rdata = 32'h12345678;
        dma_ready = 1;

        #20;
        rst_n = 1;
        pd_aes_on = 1;
        pd_aes_reset_n = 1;
        #10;

        // Step 1: Write and Read AES Key[0]
        mmio_write(32'h8000_0010, 32'hDEADBEEF);
        mmio_read(32'h8000_0010, read_val);

        $display("[UNIT SIM: aes_dma_subsys] Write KEY[0] = 0xDEADBEEF, Readback = 0x%08h", read_val);

        if (read_val !== 32'hDEADBEEF) begin
            $display("[UNIT TEST FAILED] MMIO Key[0] Register readback failed!");
            $fatal(1, "AES-DMA MMIO register verification failed");
        end

        // Step 2: In hardware-direct mode, the sequencer signal takes
        // priority over the software LOAD_MODE_EN bit.
        hw_load_mode_active = 1'b1;
        hw_load_mode_en = 1'b1;
        #1;
        if (u_dut.load_mode_en !== 1'b1) begin
            $fatal(1, "Hardware-direct AES load enable was not selected");
        end
        hw_load_mode_en = 1'b0;
        #1;
        if (u_dut.load_mode_en !== 1'b0) begin
            $fatal(1, "Hardware-direct AES load disable was not selected");
        end
        hw_load_mode_active = 1'b0;

        // Step 3: Read PRNG Output via MMIO
        mmio_read(32'h8000_0030, read_val);
        $display("[UNIT SIM: aes_dma_subsys] PRNG[0] Output via MMIO = 0x%08h", read_val);

        $display("[UNIT TEST PASSED] AES-DMA Subsystem MMIO Read/Write Verified!");
        $finish;
    end

endmodule
