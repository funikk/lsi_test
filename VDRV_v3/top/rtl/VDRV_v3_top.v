// VDRV_v3_top: Top-level wrapper module connecting VDRV_v3_core, IMEM, and DMEM.
// See VDRV_v3/docs/system_architecture/spec_top.md §8.

module VDRV_v3_top #(
    parameter TILE_ROWS    = 2,    // Number of tile rows = number of PD groups G
    parameter TILE_COLS    = 2,    // Number of standard tile columns
    parameter EDGE_COL_EN  = 1,    // 1: Add heterogeneous edge tile column
    parameter MAC_ROWS     = 4,
    parameter MAC_COLS     = 4,
    parameter EM_BUS_WIDTH = 32,
    parameter EM_FANOUT    = 64
)(
    input  wire clk,
    input  wire rst_n,

    // Scenario selection & Status outputs
    input  wire [3:0] scenario_sel,
    output wire       scenario_done,
    output wire       sig_ok,
    output wire [7:0] sig_out,
    output wire [1:0] marker,

    // UART
    input  wire uart_rx,
    output wire uart_tx,

    // Power Switch Control (Physical interface / TB observation)
    output wire [TILE_ROWS-1:0] sw_trickle_en,
    input  wire [TILE_ROWS-1:0] sw_trickle_ack,
    output wire [TILE_ROWS-1:0] sw_main_en,
    input  wire [TILE_ROWS-1:0] sw_main_ack
);

    /* verilator lint_off UNUSEDSIGNAL */
    wire trap_out;
    /* verilator lint_on UNUSEDSIGNAL */

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

    // Instantiate Core
    VDRV_v3_core #(
        .TILE_ROWS    (TILE_ROWS),
        .TILE_COLS    (TILE_COLS),
        .EDGE_COL_EN  (EDGE_COL_EN),
        .MAC_ROWS     (MAC_ROWS),
        .MAC_COLS     (MAC_COLS),
        .EM_BUS_WIDTH (EM_BUS_WIDTH),
        .EM_FANOUT    (EM_FANOUT)
    ) u_core (
        .clk            (clk),
        .rst_n          (rst_n),
        .imem_valid_o   (imem_valid),
        .imem_addr_o    (imem_addr),
        .imem_rdata_i   (imem_rdata),
        .imem_ready_i   (imem_ready),
        .dmem_valid_o   (dmem_valid),
        .dmem_wstrb_o   (dmem_wstrb),
        .dmem_addr_o    (dmem_addr),
        .dmem_wdata_o   (dmem_wdata),
        .dmem_rdata_i   (dmem_rdata),
        .dmem_ready_i   (dmem_ready),
        .trap_out       (trap_out),
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

    // Instantiate IMEM (8KB = 2048 words)
    imem #(
        .MEM_SIZE_WORDS(2048)
    ) u_imem (
        .clk   (clk),
        .rst_n (rst_n),
        .valid (imem_valid),
        .addr  (imem_addr),
        .rdata (imem_rdata),
        .ready (imem_ready)
    );

    // Instantiate DMEM (4KB = 1024 words)
    dmem #(
        .MEM_SIZE_WORDS(1024)
    ) u_dmem (
        .clk   (clk),
        .rst_n (rst_n),
        .valid (dmem_valid),
        .wstrb (dmem_wstrb),
        .addr  (dmem_addr),
        .wdata (dmem_wdata),
        .rdata (dmem_rdata),
        .ready (dmem_ready)
    );

endmodule
