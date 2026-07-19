// counter.v
module counter (
    input  wire       clk,     // System Clock
    input  wire       rst_n,   // Asynchronous Reset (Active-Low)
    input  wire       en,      // Count Enable
    output reg  [7:0] count    // 8-bit Output Count
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 8'h00;
        end else if (en) begin
            count <= count + 8'h01;
        end
    end

endmodule
