// tile_ctrl: Tile configuration register file and boundary registers.
// - Registers all incoming config/broadcast signals at the tile boundary.
// - Decodes tile-ID match (unicast / row / column / all broadcast).
// - Holds 4 pattern profiles; the active one is selected by profile_id.
// - SEED_LOAD issues a 1-cycle datapath soft reset (core_srst) followed by a
//   seed_load pulse, so that identically configured tiles restart from an
//   identical state.
// - Issues an automatic SEED_LOAD one cycle after reset release so the
//   datapath LFSR never stays at the all-zero lock-up state.
module tile_ctrl #(
    parameter [7:0] TILE_ID = 8'h00
)(
    input  wire        clk,
    input  wire        rst_n,
    // Config bus (raw, from AON)
    input  wire        cfg_valid,
    input  wire [7:0]  cfg_tile_id,
    input  wire [4:0]  cfg_addr,
    input  wire [31:0] cfg_wdata,
    input  wire        pg_sync,
    input  wire [1:0]  profile_id,
    // Active profile (registered)
    output reg  [1:0]  pg_mode,
    output reg  [4:0]  act_level,
    output reg         gate_mode,
    output reg  [15:0] pg_period,
    output reg  [15:0] pg_duty,
    output reg  [15:0] pg_phase,
    output reg         pg_sync_q,
    // Datapath control
    output reg         sig_clear,    // 1-cycle pulse
    output reg         seed_load,    // 1-cycle pulse
    output reg         core_srst,    // 1-cycle datapath soft reset (precedes seed_load)
    output wire [127:0] seed128
);
    localparam DEFAULT_SEED = 32'h1234_5678;

    // ---------------- Boundary registers ----------------
    reg        cfg_valid_q;
    reg [7:0]  cfg_tile_id_q;
    reg [4:0]  cfg_addr_q;
    reg [31:0] cfg_wdata_q;
    reg [1:0]  profile_id_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_valid_q   <= 1'b0;
            cfg_tile_id_q <= 8'h00;
            cfg_addr_q    <= 5'h00;
            cfg_wdata_q   <= 32'h0;
            pg_sync_q     <= 1'b0;
            profile_id_q  <= 2'd0;
        end else begin
            cfg_valid_q   <= cfg_valid;
            cfg_tile_id_q <= cfg_tile_id;
            cfg_addr_q    <= cfg_addr;
            cfg_wdata_q   <= cfg_wdata;
            pg_sync_q     <= pg_sync;
            profile_id_q  <= profile_id;
        end
    end

    // ---------------- Tile-ID match ----------------
    wire row_hit = (cfg_tile_id_q[7:4] == TILE_ID[7:4]) || (cfg_tile_id_q[7:4] == 4'hF);
    wire col_hit = (cfg_tile_id_q[3:0] == TILE_ID[3:0]) || (cfg_tile_id_q[3:0] == 4'hF);
    wire wr      = cfg_valid_q && row_hit && col_hit;

    // ---------------- Profile registers ----------------
    reg [1:0]  r_mode   [0:3];
    reg [4:0]  r_act    [0:3];
    reg        r_gate   [0:3];
    reg [15:0] r_period [0:3];
    reg [15:0] r_duty   [0:3];
    reg [15:0] r_phase  [0:3];
    reg [31:0] seed_reg;
    reg        seed_mix_id;
    reg        init_pending;
    reg        seed_pending;

    wire [1:0] wp = cfg_addr_q[3:2];

    integer p;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (p = 0; p < 4; p = p + 1) begin
                r_mode[p]   <= 2'd0;
                r_act[p]    <= 5'd0;
                r_gate[p]   <= 1'b0;
                r_period[p] <= 16'd0;
                r_duty[p]   <= 16'd0;
                r_phase[p]  <= 16'd0;
            end
            seed_reg     <= DEFAULT_SEED;
            seed_mix_id  <= 1'b0;
            sig_clear    <= 1'b0;
            seed_load    <= 1'b0;
            core_srst    <= 1'b0;
            init_pending <= 1'b1;
            seed_pending <= 1'b0;
        end else begin
            sig_clear    <= 1'b0;
            core_srst    <= 1'b0;
            seed_load    <= init_pending | seed_pending;
            init_pending <= 1'b0;
            seed_pending <= 1'b0;
            if (wr) begin
                if (!cfg_addr_q[4]) begin
                    case (cfg_addr_q[1:0])
                        2'd0: begin
                            r_mode[wp] <= cfg_wdata_q[1:0];
                            r_act[wp]  <= (cfg_wdata_q[8:4] > 5'd16) ? 5'd16 : cfg_wdata_q[8:4];
                            r_gate[wp] <= cfg_wdata_q[12];
                        end
                        2'd1: begin
                            r_period[wp] <= cfg_wdata_q[15:0];
                            r_duty[wp]   <= cfg_wdata_q[31:16];
                        end
                        2'd2: r_phase[wp] <= cfg_wdata_q[15:0];
                        default: ;
                    endcase
                end else begin
                    case (cfg_addr_q[3:0])
                        4'h0: begin
                            sig_clear    <= cfg_wdata_q[0];
                            // SEED_LOAD: soft-reset the datapath first, then load the seed
                            core_srst    <= cfg_wdata_q[1];
                            seed_pending <= cfg_wdata_q[1];
                            seed_mix_id <= cfg_wdata_q[2];
                        end
                        4'h1: seed_reg <= cfg_wdata_q;
                        default: ;
                    endcase
                end
            end
        end
    end

    // ---------------- Active profile select (registered) ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pg_mode   <= 2'd0;
            act_level <= 5'd0;
            gate_mode <= 1'b0;
            pg_period <= 16'd0;
            pg_duty   <= 16'd0;
            pg_phase  <= 16'd0;
        end else begin
            pg_mode   <= r_mode[profile_id_q];
            act_level <= r_act[profile_id_q];
            gate_mode <= r_gate[profile_id_q];
            pg_period <= r_period[profile_id_q];
            pg_duty   <= r_duty[profile_id_q];
            pg_phase  <= r_phase[profile_id_q];
        end
    end

    // ---------------- Seed expansion ----------------
    wire [31:0] mix = seed_mix_id ? {4{TILE_ID}} : 32'h0;
    assign seed128 = { seed_reg ^ mix,
                       seed_reg ^ 32'h9E37_79B9 ^ mix,
                       seed_reg ^ 32'h7F4A_7C15 ^ mix,
                       seed_reg ^ 32'hDEAD_BEEF ^ mix };
endmodule
