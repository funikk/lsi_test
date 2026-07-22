module cpu_aes_prng_top (
    input wire clk,
    input wire rst_n,
    output wire trap_out
);

    // IMEM Interface Wires
    wire imem_valid;
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    wire imem_ready;

    // DMEM Interface Wires
    wire dmem_valid;
    wire [3:0]  dmem_wstrb;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire dmem_ready;

    // Instantiate Intermediate Core Module (CPU + AES + PRNG + DMA + Arbiter)
    cpu_aes_prng_core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .trap_out(trap_out),
        .imem_valid_o(imem_valid),
        .imem_addr_o(imem_addr),
        .imem_rdata_i(imem_rdata),
        .imem_ready_i(imem_ready),
        .dmem_valid_o(dmem_valid),
        .dmem_wstrb_o(dmem_wstrb),
        .dmem_addr_o(dmem_addr),
        .dmem_wdata_o(dmem_wdata),
        .dmem_rdata_i(dmem_rdata),
        .dmem_ready_i(dmem_ready)
    );

    // Instantiate Instruction Memory (IMEM)
    imem u_imem (
        .clk(clk),
        .rst_n(rst_n),
        .valid(imem_valid),
        .addr(imem_addr),
        .rdata(imem_rdata),
        .ready(imem_ready)
    );

    // Instantiate Shared Data SRAM (DMEM)
    dmem u_dmem (
        .clk(clk),
        .rst_n(rst_n),
        .valid(dmem_valid),
        .wstrb(dmem_wstrb),
        .addr(dmem_addr),
        .wdata(dmem_wdata),
        .rdata(dmem_rdata),
        .ready(dmem_ready)
    );

endmodule
