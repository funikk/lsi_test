`default_nettype none

module crc_load_core #(
    parameter CHANNELS     = 4,
    parameter UNROLL_STEPS = 48,
    parameter ITER_CYCLES  = 10
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] data_in,
    input  wire [127:0] cfg_in,
    output reg  [127:0] data_out,
    output reg          ready
);

    // State machine encodings
    localparam STATE_IDLE = 1'b0;
    localparam STATE_RUN  = 1'b1;

    reg        state;
    reg [3:0]  iter_cnt;
    reg [127:0] state_reg;
    reg [127:0] cfg_reg;

    // Polynomial configuration and coefficient extraction per channel
    wire [31:0] ch_poly  [0:CHANNELS-1];
    wire [31:0] ch_coeff [0:CHANNELS-1];
    wire [31:0] ch_din   [0:CHANNELS-1];
    wire [31:0] ch_dout  [0:CHANNELS-1];

    assign ch_din[0] = state_reg[31:0];
    assign ch_din[1] = state_reg[63:32];
    assign ch_din[2] = state_reg[95:64];
    assign ch_din[3] = state_reg[127:96];

    assign ch_poly[0]  = cfg_reg[31:0];
    assign ch_poly[1]  = cfg_reg[63:32];
    assign ch_poly[2]  = cfg_reg[95:64];
    assign ch_poly[3]  = cfg_reg[127:96];

    assign ch_coeff[0] = cfg_reg[63:32];
    assign ch_coeff[1] = cfg_reg[95:64];
    assign ch_coeff[2] = cfg_reg[127:96];
    assign ch_coeff[3] = cfg_reg[31:0];

    // Instantiate parallel CRC channels
    genvar c;
    generate
        for (c = 0; c < CHANNELS; c = c + 1) begin : gen_crc_channel
            crc_channel #(
                .UNROLL_STEPS(UNROLL_STEPS)
            ) u_channel (
                .data_in  (ch_din[c]),
                .poly_in  (ch_poly[c]),
                .coeff_in (ch_coeff[c]),
                .data_out (ch_dout[c])
            );
        end
    endgenerate

    // Galois Field GF(2^8) functions for Reed-Solomon syndrome mixing
    function [7:0] gf_mult2;
        input [7:0] val;
        begin
            gf_mult2 = (val[7]) ? ((val << 1) ^ 8'h1D) : (val << 1);
        end
    endfunction

    function [7:0] gf_mult4;
        input [7:0] val;
        begin
            gf_mult4 = gf_mult2(gf_mult2(val));
        end
    endfunction

    function [7:0] gf_mult8;
        input [7:0] val;
        begin
            gf_mult8 = gf_mult2(gf_mult4(val));
        end
    endfunction

    // Cross-channel Reed-Solomon syndrome mixer
    // Evaluates syndromes across the 4 channels for each of the 4 byte lanes
    wire [127:0] mixed_state;
    genvar b;
    generate
        for (b = 0; b < 4; b = b + 1) begin : gen_rs_mixer
            wire [7:0] b0 = ch_dout[0][b*8 +: 8];
            wire [7:0] b1 = ch_dout[1][b*8 +: 8];
            wire [7:0] b2 = ch_dout[2][b*8 +: 8];
            wire [7:0] b3 = ch_dout[3][b*8 +: 8];

            // RS syndrome combinations (Vandermonde evaluation at roots alpha^0, alpha^1, alpha^2, alpha^3)
            wire [7:0] s0 = b0 ^ b1 ^ b2 ^ b3;
            wire [7:0] s1 = b0 ^ gf_mult2(b1) ^ gf_mult4(b2) ^ gf_mult8(b3);
            wire [7:0] s2 = b0 ^ gf_mult4(b1) ^ gf_mult2(b2) ^ gf_mult8(b3);
            wire [7:0] s3 = b0 ^ gf_mult8(b1) ^ gf_mult4(b2) ^ gf_mult2(b3);

            // Reassemble into mixed channels
            assign mixed_state[b*8       +: 8] = s0;
            assign mixed_state[(b+4)*8   +: 8] = s1;
            assign mixed_state[(b+8)*8   +: 8] = s2;
            assign mixed_state[(b+12)*8  +: 8] = s3;
        end
    endgenerate

    // Next configuration evolution during execution
    wire [127:0] next_cfg = {cfg_reg[126:0], cfg_reg[127]} ^
                            {32'h04C11DB7, 32'h1EDC6F41, 32'h82608EDB, 32'hA83398D3} ^
                            {124'b0, iter_cnt};

    // Sequential control & datapath registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= STATE_IDLE;
            ready     <= 1'b1;
            data_out  <= 128'b0;
            iter_cnt  <= 4'd0;
            state_reg <= 128'b0;
            cfg_reg   <= 128'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (start) begin
                        ready     <= 1'b0;
                        state     <= STATE_RUN;
                        iter_cnt  <= 4'd0;
                        state_reg <= data_in;
                        cfg_reg   <= cfg_in;
                    end else begin
                        ready     <= 1'b1;
                    end
                end

                STATE_RUN: begin
                    state_reg <= mixed_state;
                    cfg_reg   <= next_cfg;
                    iter_cnt  <= iter_cnt + 1'b1;

                    if (iter_cnt == (ITER_CYCLES - 1)) begin
                        data_out <= mixed_state;
                        ready    <= 1'b1;
                        state    <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                    ready <= 1'b1;
                end
            endcase
        end
    end

endmodule
`default_nettype wire
