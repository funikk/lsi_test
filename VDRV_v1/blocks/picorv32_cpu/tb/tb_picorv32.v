`timescale 1ns / 1ps

module tb_picorv32;

    reg clk;
    reg resetn;
    wire trap;

    wire mem_valid;
    wire mem_instr;
    reg mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wstrb;
    reg [31:0] mem_rdata;

    // Instantiate PicoRV32 Core
    picorv32 #(
        .PROGADDR_RESET(32'h0000_0000),
        .STACKADDR(32'h0000_0800)
    ) u_dut (
        .clk(clk),
        .resetn(resetn),
        .trap(trap),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .pcpi_valid(),
        .pcpi_insn(),
        .pcpi_rs1(),
        .pcpi_rs2(),
        .pcpi_wr(1'b0),
        .pcpi_rd(32'b0),
        .pcpi_wait(1'b0),
        .pcpi_ready(1'b0),
        .irq(32'b0),
        .eoi()
    );

    always #5 clk = ~clk;

    // Simple Dummy Memory Response (NOP instruction: 0x00000013 -> addi x0, x0, 0)
    always @(posedge clk) begin
        if (!resetn) begin
            mem_ready <= 1'b0;
            mem_rdata <= 32'b0;
        end else begin
            mem_ready <= mem_valid;
            if (mem_valid) begin
                mem_rdata <= 32'h00000013; // NOP instruction
            end
        end
    end

    initial begin
        clk = 0;
        resetn = 0;

        #20;
        resetn = 1;
        $display("[UNIT SIM: picorv32_cpu] Reset released. Testing memory fetch handshake...");

        // Wait for first memory fetch
        wait(mem_valid);
        @(posedge clk);

        $display("[UNIT SIM: picorv32_cpu] Memory Fetch Request Detected: Addr = 0x%08h", mem_addr);

        repeat (10) @(posedge clk);

        if (!trap) begin
            $display("[UNIT TEST PASSED] PicoRV32 Reset & Instruction Fetch Handshake Verified!");
            $finish;
        end else begin
            $display("[UNIT TEST FAILED] CPU trapped unexpectedly!");
            $fatal(1, "PicoRV32 unit verification failed");
        end
    end

endmodule
