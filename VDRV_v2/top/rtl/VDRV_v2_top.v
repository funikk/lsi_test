`include "defines.vh"

module VDRV_v2_top (
    input  wire clk,
    input  wire rst_n,

    // Original interface (can be tied off or used)
    input  wire in_valid,
    input  wire [`DATA_WIDTH-1:0] in_data,
    output wire out_valid,
    output wire [`DATA_WIDTH-1:0] out_data,

    // UART
    input  wire uart_rx,
    output wire uart_tx,

    // Load state observation
    output wire aes_load_mode_en,
    output wire [1:0] cpu_load_state
);

    wire trap_out;

    // IMEM Wires
    wire        imem_valid;
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    wire        imem_ready;

    // DMEM Wires
    wire        dmem_valid;
    wire [3:0]  dmem_wstrb;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_ready;

    VDRV_v2_core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .imem_valid_o(imem_valid),
        .imem_addr_o(imem_addr),
        .imem_rdata_i(imem_rdata),
        .imem_ready_i(imem_ready),
        .dmem_valid_o(dmem_valid),
        .dmem_wstrb_o(dmem_wstrb),
        .dmem_addr_o(dmem_addr),
        .dmem_wdata_o(dmem_wdata),
        .dmem_rdata_i(dmem_rdata),
        .dmem_ready_i(dmem_ready),
        .trap_out(trap_out),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .aes_load_mode_en(aes_load_mode_en),
        .cpu_load_state(cpu_load_state)
    );

    // Instantiate IMEM (8KB = 2048 words)
    imem #(
        .MEM_SIZE_WORDS(2048)
    ) u_imem (
        .clk(clk),
        .rst_n(rst_n),
        .valid(imem_valid),
        .addr(imem_addr),
        .rdata(imem_rdata),
        .ready(imem_ready)
    );

    // Instantiate DMEM (512B = 128 words)
    dmem #(
        .MEM_SIZE_WORDS(128)
    ) u_dmem (
        .clk(clk),
        .rst_n(rst_n),
        .valid(dmem_valid),
        .wstrb(dmem_wstrb),
        .addr(dmem_addr),
        .wdata(dmem_wdata),
        .rdata(dmem_rdata),
        .ready(dmem_ready)
    );

    // Tie off old template_block interface to prevent warnings
    assign out_valid = 0;
    assign out_data = 0;

endmodule
