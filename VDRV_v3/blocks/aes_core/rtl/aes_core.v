module aes_core(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] state_in,
    input wire [127:0] key_in,
    output reg [127:0] state_out,
    output reg ready,
    output wire busy
);

    // States
    localparam STATE_IDLE = 1'b0;
    localparam STATE_RUN  = 1'b1;

    reg state_machine;
    reg [3:0] round;
    reg [127:0] state_reg;
    reg [127:0] key_reg;

    assign busy = (state_machine != STATE_IDLE);

    // S-box Outputs
    wire [127:0] sub_bytes_out;

    // Instantiate 16 S-boxes for state SubBytes
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_sbox
            aes_sbox sb (
                .in(state_reg[127 - 8*i : 120 - 8*i]),
                .out(sub_bytes_out[127 - 8*i : 120 - 8*i])
            );
        end
    endgenerate

    // ShiftRows
    wire [127:0] shift_rows_out;
    assign shift_rows_out = {
        sub_bytes_out[127:120], sub_bytes_out[ 87: 80], sub_bytes_out[ 47: 40], sub_bytes_out[  7:  0],
        sub_bytes_out[ 95: 88], sub_bytes_out[ 55: 48], sub_bytes_out[ 15:  8], sub_bytes_out[103: 96],
        sub_bytes_out[ 63: 56], sub_bytes_out[ 23: 16], sub_bytes_out[111:104], sub_bytes_out[ 71: 64],
        sub_bytes_out[ 31: 24], sub_bytes_out[119:112], sub_bytes_out[ 79: 72], sub_bytes_out[ 39: 32]
    };

    // Helper functions for MixColumns
    function [7:0] xtime;
        input [7:0] x;
        begin
            xtime = (x[7] == 1'b1) ? ((x << 1) ^ 8'h1B) : (x << 1);
        end
    endfunction

    function [31:0] mix_col;
        input [31:0] col;
        reg [7:0] a0, a1, a2, a3;
        reg [7:0] r0, r1, r2, r3;
        begin
            a0 = col[31:24];
            a1 = col[23:16];
            a2 = col[15:8];
            a3 = col[7:0];

            r0 = xtime(a0) ^ (xtime(a1) ^ a1) ^ a2 ^ a3;
            r1 = a0 ^ xtime(a1) ^ (xtime(a2) ^ a2) ^ a3;
            r2 = a0 ^ a1 ^ xtime(a2) ^ (xtime(a3) ^ a3);
            r3 = (xtime(a0) ^ a0) ^ a1 ^ a2 ^ xtime(a3);

            mix_col = {r0, r1, r2, r3};
        end
    endfunction

    // MixColumns
    wire [127:0] mix_cols_out;
    assign mix_cols_out[127:96] = mix_col(shift_rows_out[127:96]);
    assign mix_cols_out[95:64]  = mix_col(shift_rows_out[95:64]);
    assign mix_cols_out[63:32]  = mix_col(shift_rows_out[63:32]);
    assign mix_cols_out[31:0]   = mix_col(shift_rows_out[31:0]);

    // Key Expansion Helpers
    function [7:0] rcon;
        input [3:0] round_val;
        case (round_val)
            4'd1:  rcon = 8'h01;
            4'd2:  rcon = 8'h02;
            4'd3:  rcon = 8'h04;
            4'd4:  rcon = 8'h08;
            4'd5:  rcon = 8'h10;
            4'd6:  rcon = 8'h20;
            4'd7:  rcon = 8'h40;
            4'd8:  rcon = 8'h80;
            4'd9:  rcon = 8'h1b;
            4'd10: rcon = 8'h36;
            default: rcon = 8'h00;
        endcase
    endfunction

    // Key Expansion Logic
    wire [31:0] w0 = key_reg[127:96];
    wire [31:0] w1 = key_reg[95:64];
    wire [31:0] w2 = key_reg[63:32];
    wire [31:0] w3 = key_reg[31:0];

    wire [31:0] rot_w3 = {w3[23:0], w3[31:24]};
    wire [31:0] sub_w3;

    aes_sbox sb_k0 (.in(rot_w3[31:24]), .out(sub_w3[31:24]));
    aes_sbox sb_k1 (.in(rot_w3[23:16]), .out(sub_w3[23:16]));
    aes_sbox sb_k2 (.in(rot_w3[15:8]),  .out(sub_w3[15:8]));
    aes_sbox sb_k3 (.in(rot_w3[7:0]),   .out(sub_w3[7:0]));

    wire [31:0] g = sub_w3 ^ {rcon(round), 24'b0};

    wire [31:0] next_w0 = w0 ^ g;
    wire [31:0] next_w1 = w1 ^ next_w0;
    wire [31:0] next_w2 = w2 ^ next_w1;
    wire [31:0] next_w3 = w3 ^ next_w2;

    wire [127:0] next_key = {next_w0, next_w1, next_w2, next_w3};

    // State Machine & Registers
    always @(posedge clk) begin
        if (!rst_n) begin
            state_machine <= STATE_IDLE;
            round         <= 4'd0;
            state_reg     <= 128'b0;
            key_reg       <= 128'b0;
            state_out     <= 128'b0;
            ready         <= 1'b0;
        end else begin
            case (state_machine)
                STATE_IDLE: begin
                    ready <= 1'b0;
                    if (start) begin
                        state_reg     <= state_in ^ key_in; // AddRoundKey (Pre-round 0)
                        key_reg       <= key_in;
                        round         <= 4'd1;
                        state_machine <= STATE_RUN;
                    end
                end

                STATE_RUN: begin
                    key_reg <= next_key;
                    round   <= round + 1'b1;

                    if (round < 4'd10) begin
                        state_reg <= mix_cols_out ^ next_key;
                    end else if (round == 4'd10) begin
                        state_reg     <= shift_rows_out ^ next_key;
                        state_machine <= STATE_IDLE;
                    end
                end
            endcase

            // Output logic
            if (state_machine == STATE_RUN && round == 4'd10) begin
                state_out <= shift_rows_out ^ next_key;
                ready     <= 1'b1;
            end
        end
    end

endmodule
