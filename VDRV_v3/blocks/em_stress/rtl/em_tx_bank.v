module em_tx_bank #(
    parameter W = 32
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         en,
    input  wire         pattern,   // 0: alternating toggle, 1: LFSR
    output wire [W-1:0] tx_data
);

    (* keep *) reg [W-1:0] tx_reg;
    assign tx_data = tx_reg;

    wire [W-1:0] reset_val;
    genvar gi;
    generate
        for (gi = 0; gi < W; gi = gi + 1) begin : gen_tx_rst
            assign reset_val[gi] = (gi % 2 == 0) ? 1'b1 : 1'b0;
        end
    endgenerate

    wire lfsr_fb = tx_reg[W-1] ^ tx_reg[(W > 22 ? 21 : 0)] ^ tx_reg[(W > 2 ? 1 : 0)] ^ tx_reg[0];
    wire next_fb = lfsr_fb ^ (tx_reg == {W{1'b0}});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_reg <= reset_val;
        end else if (en) begin
            if (!pattern) begin
                tx_reg <= ~tx_reg;
            end else begin
                tx_reg <= {tx_reg[W-2:0], next_fb};
            end
        end
    end

endmodule
