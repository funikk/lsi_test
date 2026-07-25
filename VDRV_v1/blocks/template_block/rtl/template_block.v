`include "defines.vh"

module template_block (
    input  wire clk,
    input  wire rst_n,
    input  wire in_valid,
    input  wire [`DATA_WIDTH-1:0] in_data,
    output reg  out_valid,
    output reg  [`DATA_WIDTH-1:0] out_data
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_data  <= {`DATA_WIDTH{1'b0}};
        end else begin
            out_valid <= in_valid;
            out_data  <= in_data;
        end
    end

endmodule
