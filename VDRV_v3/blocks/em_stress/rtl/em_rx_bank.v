module em_rx_bank #(
    parameter W = 32
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire [W-1:0] rx_in,
    output wire [W-1:0] rx_data
);

    (* keep *) reg [W-1:0] rx_reg;
    assign rx_data = rx_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_reg <= {W{1'b0}};
        end else begin
            rx_reg <= rx_in;
        end
    end

endmodule
