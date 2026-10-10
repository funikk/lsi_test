// tile_pattern_gen: Cycle-accurate load pattern generator (lower layer).
// PG_MODE: 0=OFF, 1=always ON, 2=periodic (pc < DUTY), 3=random burst (LFSR MSB).
// pg_sync reloads the phase counter with PG_PHASE so that all tiles can be
// aligned (same phase) or staggered (different phases).
module tile_pattern_gen (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  pg_mode,
    input  wire [15:0] pg_period,
    input  wire [15:0] pg_duty,
    input  wire [15:0] pg_phase,
    input  wire        pg_sync,
    output reg         load_on
);
    reg  [15:0] pc;
    reg  [15:0] rnd;
    wire [15:0] period_eff = (pg_period == 16'd0) ? 16'd1 : pg_period;
    wire [16:0] pc_inc     = {1'b0, pc} + 17'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc  <= 16'd0;
            rnd <= 16'hACE1;
        end else begin
            if (pg_sync)
                pc <= pg_phase;
            else if (pc_inc >= {1'b0, period_eff})
                pc <= 16'd0;
            else
                pc <= pc_inc[15:0];
            // 16-bit Fibonacci LFSR x^16 + x^14 + x^13 + x^11 + 1
            rnd <= {rnd[14:0], rnd[15] ^ rnd[13] ^ rnd[12] ^ rnd[10]};
        end
    end

    // Registered output: load_on reflects the state of pc/rnd one cycle later.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_on <= 1'b0;
        end else begin
            case (pg_mode)
                2'd0:    load_on <= 1'b0;
                2'd1:    load_on <= 1'b1;
                2'd2:    load_on <= (pc < pg_duty);
                default: load_on <= rnd[15];
            endcase
        end
    end
endmodule
