// VDRV_v3_core: Top core logic integrating PicoRV32 CPU, AON peripherals,
// and the parameterizable load tile array with per-row power domains.
// See VDRV_v3/docs/system_architecture/spec_top.md and
// VDRV_v3/docs/logic_design/spec_module_interfaces.md §9.

module VDRV_v3_core #(
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

    // Instruction Memory Interface (IMEM)
    output wire        imem_valid_o,
    output wire [31:0] imem_addr_o,
    input  wire [31:0] imem_rdata_i,
    input  wire        imem_ready_i,

    // Data SRAM Interface (DMEM)
    output wire        dmem_valid_o,
    output wire [3:0]  dmem_wstrb_o,
    output wire [31:0] dmem_addr_o,
    output wire [31:0] dmem_wdata_o,
    input  wire [31:0] dmem_rdata_i,
    input  wire        dmem_ready_i,

    output wire trap_out,

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

    localparam G = TILE_ROWS;
    localparam COLS_TOTAL = TILE_COLS + (EDGE_COL_EN ? 1 : 0);
    localparam NUM_TILES  = TILE_ROWS * COLS_TOTAL;

    // ----------------------------------------------------
    // CPU Signals & Instantiation
    // ----------------------------------------------------
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;
    wire [31:0] irq;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [31:0] eoi;
    /* verilator lint_on UNUSEDSIGNAL */

    wire cpu_irq; // From load_sequencer
    assign irq[31:4] = 28'd0;
    assign irq[3]    = cpu_irq;
    assign irq[2:0]  = 3'd0;

    picorv32 #(
        .ENABLE_IRQ(1),
        .ENABLE_IRQ_QREGS(1),
        .ENABLE_IRQ_TIMER(1),
        .PROGADDR_RESET(32'h0000_0000),
        .STACKADDR(32'h0000_0800)
    ) u_cpu (
        .clk         (clk),
        .resetn      (rst_n),
        .trap        (trap_out),
        .mem_valid   (mem_valid),
        .mem_instr   (mem_instr),
        .mem_ready   (mem_ready),
        .mem_addr    (mem_addr),
        .mem_wdata   (mem_wdata),
        .mem_wstrb   (mem_wstrb),
        .mem_rdata   (mem_rdata),
        .irq         (irq),
        .eoi         (eoi)
    );

    // IMEM route
    assign imem_valid_o = mem_valid && mem_instr;
    assign imem_addr_o  = mem_addr;

    // Data bus demux
    wire cpu_data_req = mem_valid && !mem_instr;
    wire is_mmio      = mem_addr[31]; // 0x8000_0000+

    assign dmem_valid_o = cpu_data_req && !is_mmio;
    assign dmem_wstrb_o = mem_wstrb;
    assign dmem_addr_o  = mem_addr;
    assign dmem_wdata_o = mem_wdata;

    wire cpu_mmio_req = cpu_data_req && is_mmio;

    // ----------------------------------------------------
    // MMIO Address Decoding
    // 0x8000_0000 - 0x8000_00FF : sys_ctrl
    // 0x8000_0100 - 0x8000_01FF : load_sequencer
    // 0x8000_0200 - 0x8000_02FF : pwr_manager
    // 0x8000_0300 - 0x8000_03FF : tile_cfg_bridge
    // 0x8000_0400 - 0x8000_04FF : em_stress
    // 0x8000_0500 - 0x8000_05FF : uart_ctrl
    // ----------------------------------------------------
    wire [7:0] mmio_offset = mem_addr[7:0];

    wire sel_sys_ctrl    = cpu_mmio_req && (mem_addr[31:8] == 24'h8000_00);
    wire sel_load_seq    = cpu_mmio_req && (mem_addr[31:8] == 24'h8000_01);
    wire sel_pwr_mgr     = cpu_mmio_req && (mem_addr[31:8] == 24'h8000_02);
    wire sel_cfg_bridge  = cpu_mmio_req && (mem_addr[31:8] == 24'h8000_03);
    wire sel_em_stress   = cpu_mmio_req && (mem_addr[31:8] == 24'h8000_04);

    wire [31:0] rdata_sys_ctrl;
    wire        ready_sys_ctrl;
    wire [31:0] rdata_load_seq;
    wire        ready_load_seq;
    wire [31:0] rdata_pwr_mgr;
    wire        ready_pwr_mgr;
    wire [31:0] rdata_cfg_bridge;
    wire        ready_cfg_bridge;
    wire [31:0] rdata_em_stress;
    wire        ready_em_stress;

    // CPU Bus Multiplexer
    assign mem_ready = mem_instr ? imem_ready_i :
                       (sel_sys_ctrl   ? ready_sys_ctrl :
                       (sel_load_seq   ? ready_load_seq :
                       (sel_pwr_mgr    ? ready_pwr_mgr :
                       (sel_cfg_bridge ? ready_cfg_bridge :
                       (sel_em_stress  ? ready_em_stress :
                       (is_mmio        ? 1'b1 : dmem_ready_i))))));

    assign mem_rdata = mem_instr ? imem_rdata_i :
                       (sel_sys_ctrl   ? rdata_sys_ctrl :
                       (sel_load_seq   ? rdata_load_seq :
                       (sel_pwr_mgr    ? rdata_pwr_mgr :
                       (sel_cfg_bridge ? rdata_cfg_bridge :
                       (sel_em_stress  ? rdata_em_stress :
                       (is_mmio        ? 32'h0 : dmem_rdata_i))))));

    // ----------------------------------------------------
    // UART Controller
    // ----------------------------------------------------
    wire cmd_set_step;
    wire cmd_start_seq;
    wire cmd_stop_seq;
    wire [3:0]  step_id;
    wire [1:0]  step_state;
    wire [15:0] step_duration;

    uart_ctrl u_uart (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx            (uart_rx),
        .tx            (uart_tx),
        .cmd_set_step  (cmd_set_step),
        .cmd_start_seq (cmd_start_seq),
        .cmd_stop_seq  (cmd_stop_seq),
        .step_id       (step_id),
        .step_state    (step_state),
        .step_duration (step_duration)
    );

    // ----------------------------------------------------
    // System Controller (sys_ctrl)
    // ----------------------------------------------------
    wire [1:0] sw_marker;

    sys_ctrl u_sys_ctrl (
        .clk           (clk),
        .rst_n         (rst_n),
        .mmio_valid    (sel_sys_ctrl),
        .mmio_addr     (mmio_offset),
        .mmio_wstrb    (mem_wstrb),
        .mmio_wdata    (mem_wdata),
        .mmio_rdata    (rdata_sys_ctrl),
        .mmio_ready    (ready_sys_ctrl),
        .scenario_sel  (scenario_sel),
        .scenario_done (scenario_done),
        .sig_ok        (sig_ok),
        .sw_marker     (sw_marker),
        .sig_out       (sig_out)
    );

    // ----------------------------------------------------
    // Load Sequencer (load_sequencer)
    // ----------------------------------------------------
    wire       hw_direct_active;
    wire       seq_running;
    wire       seq_done;
    wire       seq_pg_sync;
    wire [1:0] cur_profile_id;
    wire [7:0] cur_pd_req;
    wire [1:0] cur_marker;
    wire [2:0] cur_em_ctrl;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [3:0] cur_step;
    /* verilator lint_on UNUSEDSIGNAL */

    load_sequencer u_load_seq (
        .clk           (clk),
        .rst_n         (rst_n),
        .cmd_set_step  (cmd_set_step),
        .cmd_start_seq (cmd_start_seq),
        .cmd_stop_seq  (cmd_stop_seq),
        .step_id       (step_id),
        .step_state    (step_state),
        .step_duration (step_duration),
        .mmio_valid    (sel_load_seq),
        .mmio_addr     (mmio_offset),
        .mmio_wstrb    (mem_wstrb),
        .mmio_wdata    (mem_wdata),
        .mmio_rdata    (rdata_load_seq),
        .mmio_ready    (ready_load_seq),
        .hw_direct_active (hw_direct_active),
        .running       (seq_running),
        .seq_done      (seq_done),
        .seq_pg_sync   (seq_pg_sync),
        .cur_profile_id(cur_profile_id),
        .cur_pd_req    (cur_pd_req),
        .cur_marker    (cur_marker),
        .cur_em_ctrl   (cur_em_ctrl),
        .cur_step      (cur_step),
        .cpu_irq       (cpu_irq)
    );

    assign marker = hw_direct_active ? cur_marker : sw_marker;

    // ----------------------------------------------------
    // Power Manager (pwr_manager)
    // ----------------------------------------------------
    wire [G-1:0] iso_en;
    wire [G-1:0] pd_rst_n;
    wire [G-1:0] pd_on;

    pwr_manager #(
        .G(G)
    ) u_pwr_mgr (
        .clk              (clk),
        .rst_n            (rst_n),
        .mmio_valid       (sel_pwr_mgr),
        .mmio_addr        (mmio_offset),
        .mmio_wstrb       (mem_wstrb),
        .mmio_wdata       (mem_wdata),
        .mmio_rdata       (rdata_pwr_mgr),
        .mmio_ready       (ready_pwr_mgr),
        .hw_direct_active (hw_direct_active),
        .hw_pd_req        (cur_pd_req),
        .sw_trickle_en    (sw_trickle_en),
        .sw_trickle_ack   (sw_trickle_ack),
        .sw_main_en       (sw_main_en),
        .sw_main_ack      (sw_main_ack),
        .iso_en           (iso_en),
        .pd_rst_n         (pd_rst_n),
        .pd_on            (pd_on)
    );

    // ----------------------------------------------------
    // EM Stress Block (em_stress)
    // ----------------------------------------------------
    em_stress #(
        .W(EM_BUS_WIDTH),
        .FANOUT(EM_FANOUT)
    ) u_em_stress (
        .clk              (clk),
        .rst_n            (rst_n),
        .mmio_valid       (sel_em_stress),
        .mmio_addr        (mmio_offset),
        .mmio_wstrb       (mem_wstrb),
        .mmio_wdata       (mem_wdata),
        .mmio_rdata       (rdata_em_stress),
        .mmio_ready       (ready_em_stress),
        .hw_direct_active (hw_direct_active),
        .hw_em_ctrl       (cur_em_ctrl)
    );

    // ----------------------------------------------------
    // Tile Config Bridge (tile_cfg_bridge)
    // ----------------------------------------------------
    wire                  cfg_valid;
    wire [7:0]           cfg_tile_id;
    wire [4:0]           cfg_addr;
    wire [31:0]          cfg_wdata;
    wire                 sw_pg_sync;
    wire [1:0]           sw_profile_id;
    wire [NUM_TILES*32-1:0] tile_sig_isolated;

    tile_cfg_bridge #(
        .NT(NUM_TILES)
    ) u_cfg_bridge (
        .clk           (clk),
        .rst_n         (rst_n),
        .mmio_valid    (sel_cfg_bridge),
        .mmio_addr     (mmio_offset),
        .mmio_wstrb    (mem_wstrb),
        .mmio_wdata    (mem_wdata),
        .mmio_rdata    (rdata_cfg_bridge),
        .mmio_ready    (ready_cfg_bridge),
        .cfg_valid     (cfg_valid),
        .cfg_tile_id   (cfg_tile_id),
        .cfg_addr      (cfg_addr),
        .cfg_wdata     (cfg_wdata),
        .sw_pg_sync    (sw_pg_sync),
        .sw_profile_id (sw_profile_id),
        .tile_sig      (tile_sig_isolated)
    );

    // Effective profile_id and broadcast sync pulse
    wire [1:0] profile_id_eff = hw_direct_active ? cur_profile_id : sw_profile_id;
    wire       pg_sync_pulse  = seq_pg_sync | sw_pg_sync;

    // Register broadcast signals before distributing to tile array
    reg       pg_sync_dist;
    reg [1:0] profile_id_dist;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pg_sync_dist    <= 1'b0;
            profile_id_dist <= 2'b00;
        end else begin
            pg_sync_dist    <= pg_sync_pulse;
            profile_id_dist <= profile_id_eff;
        end
    end

    // ----------------------------------------------------
    // Tile Array Instantiation
    // ----------------------------------------------------
    wire [NUM_TILES*32-1:0] tile_sig_raw;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [NUM_TILES-1:0]    tile_active_raw;
    /* verilator lint_on UNUSEDSIGNAL */

    genvar r, c;
    generate
        for (r = 0; r < TILE_ROWS; r = r + 1) begin : gen_row
            // Tile row reset: combined global rst_n and power manager pd_rst_n
            wire row_rst_n = rst_n & pd_rst_n[r];

            for (c = 0; c < COLS_TOTAL; c = c + 1) begin : gen_col
                localparam TILE_IDX = r * COLS_TOTAL + c;
                localparam [7:0] TILE_ID_VAL = {r[3:0], c[3:0]};

                // Standard tiles vs Edge column
                // Edge column (if enabled and c == TILE_COLS):
                //   even rows (r%2==0): low-activity tile (TILE_TYPE = 1)
                //   odd rows  (r%2==1): SRAM tile (TILE_TYPE = 2)
                localparam TILE_TYPE_VAL = (EDGE_COL_EN && (c == TILE_COLS)) ?
                                           ((r % 2 == 0) ? 1 : 2) : 0;

                wire [31:0] t_sig;
                wire        t_act;

                load_tile #(
                    .TILE_TYPE (TILE_TYPE_VAL),
                    .TILE_ID   (TILE_ID_VAL),
                    .MAC_ROWS  (MAC_ROWS),
                    .MAC_COLS  (MAC_COLS)
                ) u_tile (
                    .clk         (clk),
                    .rst_n       (row_rst_n),
                    .cfg_valid   (cfg_valid),
                    .cfg_tile_id (cfg_tile_id),
                    .cfg_addr    (cfg_addr),
                    .cfg_wdata   (cfg_wdata),
                    .pg_sync     (pg_sync_dist),
                    .profile_id  (profile_id_dist),
                    .sig_out     (t_sig),
                    .load_active (t_act)
                );

                assign tile_sig_raw[TILE_IDX*32 +: 32] = t_sig;
                assign tile_active_raw[TILE_IDX]       = t_act;

                // Power-aware isolation (and simulation-time X propagation)
`ifdef POWER_AWARE_SIM
                wire [31:0] t_sig_pa = pd_on[r] ? t_sig : 32'hxxxx_xxxx;
`else
                wire [31:0] t_sig_pa = t_sig;
`endif

                vdrv_iso_and #(
                    .W(32)
                ) u_iso (
                    .iso_en (iso_en[r]),
                    .d      (t_sig_pa),
                    .q      (tile_sig_isolated[TILE_IDX*32 +: 32])
                );
            end
        end
    endgenerate

endmodule
