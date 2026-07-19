module mac_unit #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 16
)(
    input clk,
    input rst_n,
    input en,
    input [DATA_WIDTH-1:0] a_in,
    input [DATA_WIDTH-1:0] b_in,
    input [ACC_WIDTH-1:0] c_in,
    output reg [DATA_WIDTH-1:0] a_out,
    output reg [DATA_WIDTH-1:0] b_out,
    output reg [ACC_WIDTH-1:0] mac_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= 0;
            b_out <= 0;
            mac_out <= 0;
        end else if (en) begin
            a_out <= a_in;
            b_out <= b_in;
            mac_out <= c_in + (a_in * b_in);
        end
    end
endmodule
