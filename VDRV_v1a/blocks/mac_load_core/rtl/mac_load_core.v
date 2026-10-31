module mac_load_core #(
    parameter ROWS        = 5,
    parameter COLS        = 4,
    parameter DATA_WIDTH  = 8,
    parameter ACC_WIDTH   = 16,
    parameter ITER_CYCLES = 10
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] data_in,
    input  wire [127:0] cfg_in,
    output reg  [127:0] data_out,
    output reg          ready
);

    // FSM States
    localparam STATE_IDLE = 1'b0;
    localparam STATE_RUN  = 1'b1;

    reg state_machine;
    reg [31:0] iter_cnt;
    reg [127:0] state_reg;
    reg [127:0] cfg_reg;

    // MAC array signals
    wire [(ROWS*DATA_WIDTH)-1:0] a_in;
    wire [(COLS*DATA_WIDTH)-1:0] b_in;
    wire [(COLS*ACC_WIDTH)-1:0]  c_in;

    wire [(ROWS*DATA_WIDTH)-1:0] a_out;
    wire [(COLS*DATA_WIDTH)-1:0] b_out;
    wire [(COLS*ACC_WIDTH)-1:0]  mac_out;

    wire en          = (state_machine == STATE_RUN);
    wire array_rst_n = rst_n & (state_machine == STATE_RUN);

    // Map internal registers to MAC inputs
    genvar g_i, g_j;
    generate
        for (g_i = 0; g_i < ROWS * DATA_WIDTH; g_i = g_i + 1) begin : gen_a_bits
            assign a_in[g_i] = state_reg[(g_i * 3 + 1) % 128] ^ cfg_reg[(g_i * 5 + 7) % 128];
        end
        for (g_j = 0; g_j < COLS * DATA_WIDTH; g_j = g_j + 1) begin : gen_b_bits
            assign b_in[g_j] = cfg_reg[(g_j * 7 + 13) % 128] ^ state_reg[(g_j * 11 + 3) % 128];
        end
        for (g_j = 0; g_j < COLS * ACC_WIDTH; g_j = g_j + 1) begin : gen_c_bits
            assign c_in[g_j] = state_reg[(g_j * 13 + 29) % 128] ^ cfg_reg[(g_j * 17 + 19) % 128];
        end
    endgenerate

    // Feedback mapping from MAC array outputs to 128-bit mix
    localparam MAC_OUT_BITS = (ROWS * DATA_WIDTH) + (COLS * DATA_WIDTH) + (COLS * ACC_WIDTH);
    localparam SLICES = (MAC_OUT_BITS + 127) / 128;

    wire [SLICES*128-1:0] padded_mac_all_out;
    assign padded_mac_all_out = { {((SLICES * 128) - MAC_OUT_BITS){1'b0}}, a_out, b_out, mac_out };

    function [127:0] fold_slices;
        input [SLICES*128-1:0] in_vector;
        integer s;
        reg [127:0] res;
        begin
            res = 128'b0;
            for (s = 0; s < SLICES; s = s + 1) begin
                res = res ^ in_vector[s*128 +: 128];
            end
            fold_slices = res;
        end
    endfunction

    wire [127:0] feedback_mix = fold_slices(padded_mac_all_out);

    // Next round values
    wire [127:0] next_state = {state_reg[114:0], state_reg[127:115]} ^ cfg_reg ^ feedback_mix;
    wire [127:0] next_cfg   = {cfg_reg[96:0], cfg_reg[127:97]} ^ {feedback_mix[63:0], feedback_mix[127:64]} ^ {4{24'h5A5A5A, iter_cnt[7:0]}};

    // Instantiate MAC Array
    mac_array #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_mac_array (
        .clk(clk),
        .rst_n(array_rst_n),
        .en(en),
        .a_in(a_in),
        .b_in(b_in),
        .c_in(c_in),
        .a_out(a_out),
        .b_out(b_out),
        .mac_out(mac_out)
    );

    // State machine & control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_machine <= STATE_IDLE;
            iter_cnt      <= 32'd0;
            state_reg     <= 128'b0;
            cfg_reg       <= 128'b0;
            data_out      <= 128'b0;
            ready         <= 1'b1;
        end else begin
            case (state_machine)
                STATE_IDLE: begin
                    ready <= 1'b1;
                    if (start) begin
                        state_reg     <= data_in;
                        cfg_reg       <= cfg_in;
                        iter_cnt      <= 32'd0;
                        ready         <= 1'b0;
                        state_machine <= STATE_RUN;
                    end
                end

                STATE_RUN: begin
                    state_reg <= next_state;
                    cfg_reg   <= next_cfg;

                    if (iter_cnt == (ITER_CYCLES - 1)) begin
                        state_machine <= STATE_IDLE;
                        ready         <= 1'b1;
                        data_out      <= next_state;
                    end else begin
                        iter_cnt <= iter_cnt + 1'b1;
                    end
                end

                default: begin
                    state_machine <= STATE_IDLE;
                    ready         <= 1'b1;
                end
            endcase
        end
    end

endmodule
