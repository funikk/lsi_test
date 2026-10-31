module dmem #(
    parameter MEM_SIZE_WORDS = 2048 // 8KB (2048 x 32 bits)
)(
    input wire clk,
    input wire rst_n,
    input wire valid,
    input wire [3:0] wstrb,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output reg [31:0] rdata,
    output reg ready
);
    reg [31:0] mem [0:MEM_SIZE_WORDS-1];

    wire [31:0] word_addr = {2'b00, addr[31:2]};

    always @(posedge clk) begin
        if (!rst_n) begin
            ready <= 1'b0;
            rdata <= 32'b0;
        end else begin
            ready <= valid;
            if (valid) begin
                if (wstrb[0]) mem[word_addr % MEM_SIZE_WORDS][ 7: 0] <= wdata[ 7: 0];
                if (wstrb[1]) mem[word_addr % MEM_SIZE_WORDS][15: 8] <= wdata[15: 8];
                if (wstrb[2]) mem[word_addr % MEM_SIZE_WORDS][23:16] <= wdata[23:16];
                if (wstrb[3]) mem[word_addr % MEM_SIZE_WORDS][31:24] <= wdata[31:24];
                rdata <= mem[word_addr % MEM_SIZE_WORDS];
            end
        end
    end
endmodule
