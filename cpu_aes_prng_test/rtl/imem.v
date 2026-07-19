module imem #(
    parameter MEM_SIZE_WORDS = 2048 // 8KB (2048 x 32 bits)
)(
    input wire clk,
    input wire rst_n,
    input wire valid,
    input wire [31:0] addr,
    output reg [31:0] rdata,
    output reg ready
);
    reg [31:0] mem [0:MEM_SIZE_WORDS-1];

    // Optional initial firmware file
    initial begin
        $readmemh("firmware.hex", mem);
    end

    wire [31:0] word_addr = addr[31:2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b0;
            rdata <= 32'b0;
        end else begin
            ready <= valid;
            if (valid) begin
                rdata <= mem[word_addr % MEM_SIZE_WORDS];
            end
        end
    end
endmodule
