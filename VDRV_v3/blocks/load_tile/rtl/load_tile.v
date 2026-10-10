// load_tile: Top of one load tile (see docs/logic_design/spec_module_interfaces.md §3).
// Ungated domain : tile_ctrl, tile_pattern_gen, output register.
// Gated domain   : tile core (std / lowact / sram) behind vdrv_icg.
// All tile-boundary inputs and outputs are registered.
// Note: the reused aes_core uses a synchronous reset while tile flops use an
// asynchronous one; Verilator SYNCASYNCNET is waived at block/top level.
module load_tile #(
    parameter TILE_TYPE  = 0,        // 0: standard, 1: low-activity, 2: SRAM
    parameter [7:0] TILE_ID = 8'h00, // {row[3:0], col[3:0]}
    parameter MAC_ROWS   = 4,
    parameter MAC_COLS   = 4,
    parameter LOWACT_FFS = 4096,
    parameter SRAM_AW    = 6,
    parameter SRAM_BANKS = 2
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        cfg_valid,
    input  wire [7:0]  cfg_tile_id,
    input  wire [4:0]  cfg_addr,
    input  wire [31:0] cfg_wdata,
    input  wire        pg_sync,
    input  wire [1:0]  profile_id,
    output wire [31:0] sig_out,
    output wire        load_active
);
    wire [1:0]   pg_mode;
    wire [4:0]   act_level;
    wire         gate_mode;
    wire [15:0]  pg_period, pg_duty, pg_phase;
    wire         pg_sync_q;
    wire         sig_clear, seed_load, core_srst;
    wire [127:0] seed128;

    tile_ctrl #(.TILE_ID(TILE_ID)) u_ctrl (
        .clk(clk), .rst_n(rst_n),
        .cfg_valid(cfg_valid), .cfg_tile_id(cfg_tile_id), .cfg_addr(cfg_addr), .cfg_wdata(cfg_wdata),
        .pg_sync(pg_sync), .profile_id(profile_id),
        .pg_mode(pg_mode), .act_level(act_level), .gate_mode(gate_mode),
        .pg_period(pg_period), .pg_duty(pg_duty), .pg_phase(pg_phase), .pg_sync_q(pg_sync_q),
        .sig_clear(sig_clear), .seed_load(seed_load), .core_srst(core_srst), .seed128(seed128)
    );

    // Datapath reset: global/PD reset or 1-cycle soft reset. core_srst is a
    // flop output (glitch-free), asserted for one full cycle.
    wire core_rst_n = rst_n & ~core_srst;

    wire load_on;
    tile_pattern_gen u_pg (
        .clk(clk), .rst_n(rst_n),
        .pg_mode(pg_mode), .pg_period(pg_period), .pg_duty(pg_duty), .pg_phase(pg_phase),
        .pg_sync(pg_sync_q), .load_on(load_on)
    );
    assign load_active = load_on;

    // Clock gating: in GATE_MODE the core clock runs only while the load is on
    // (or for a pending control pulse). Otherwise the clock is free-running and
    // the load is stopped by holding data (en=0).
    wire icg_en = ~gate_mode | load_on | sig_clear | seed_load | core_srst;
    wire gclk;
    vdrv_icg u_icg (.clk_i(clk), .en_i(icg_en), .te_i(1'b0), .clk_o(gclk));

    wire [31:0] core_sig;
    generate
        if (TILE_TYPE == 1) begin : g_lowact
            tile_core_lowact #(.LOWACT_FFS(LOWACT_FFS)) u_core (
                .gclk(gclk), .rst_n(core_rst_n), .en(load_on), .act_level(act_level),
                .seed_load(seed_load), .seed128(seed128), .sig_clear(sig_clear), .sig(core_sig)
            );
        end else if (TILE_TYPE == 2) begin : g_sram
            tile_core_sram #(.SRAM_AW(SRAM_AW), .SRAM_BANKS(SRAM_BANKS)) u_core (
                .gclk(gclk), .rst_n(core_rst_n), .en(load_on), .act_level(act_level),
                .seed_load(seed_load), .seed128(seed128), .sig_clear(sig_clear), .sig(core_sig)
            );
        end else begin : g_std
            tile_core_std #(.MAC_ROWS(MAC_ROWS), .MAC_COLS(MAC_COLS)) u_core (
                .gclk(gclk), .rst_n(core_rst_n), .en(load_on), .act_level(act_level),
                .seed_load(seed_load), .seed128(seed128), .sig_clear(sig_clear), .sig(core_sig)
            );
        end
    endgenerate

    reg [31:0] sig_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sig_q <= 32'h0;
        else
            sig_q <= core_sig;
    end
    assign sig_out = sig_q;
endmodule
