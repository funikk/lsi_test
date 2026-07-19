// async_fifo.v
// Parameterized Asynchronous FIFO for crossing clock domains safely
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4  // DEPTH = 2^ADDR_WIDTH (must be power of 2)
) (
    // Write Clock Domain
    input  wire                    wr_clk,
    input  wire                    wr_rst_n,
    input  wire                    wr_en,
    input  wire [DATA_WIDTH-1:0]   data_in,
    output wire                    wr_full,

    // Read Clock Domain
    input  wire                    rd_clk,
    input  wire                    rd_rst_n,
    input  wire                    rd_en,
    output reg  [DATA_WIDTH-1:0]   data_out,
    output wire                    rd_empty
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    // Dual-port Memory Array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Binary Pointers (size ADDR_WIDTH + 1 to check full/empty condition)
    reg [ADDR_WIDTH:0] wr_ptr_bin;
    reg [ADDR_WIDTH:0] rd_ptr_bin;

    // Gray Pointers
    reg [ADDR_WIDTH:0] wr_ptr_gray;
    reg [ADDR_WIDTH:0] rd_ptr_gray;

    // Synchronizer registers
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync_d1;
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync_d2;
    reg [ADDR_WIDTH:0] rd_ptr_gray_sync_d1;
    reg [ADDR_WIDTH:0] rd_ptr_gray_sync_d2;

    // ----------------------------------------------------
    // Write Clock Domain Logic
    // ----------------------------------------------------

    // Binary and Gray Pointer increment
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= 0;
            wr_ptr_gray <= 0;
        end else if (wr_en && !wr_full) begin
            wr_ptr_bin  <= wr_ptr_bin + 1'b1;
            wr_ptr_gray <= (wr_ptr_bin + 1'b1) ^ ((wr_ptr_bin + 1'b1) >> 1);
        end
    end

    // Write to memory
    always @(posedge wr_clk) begin
        if (wr_en && !wr_full) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= data_in;
        end
    end

    // Synchronize Read Pointer (Gray) into Write Domain (2-stage D-FF)
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_sync_d1 <= 0;
            rd_ptr_gray_sync_d2 <= 0;
        end else begin
            rd_ptr_gray_sync_d1 <= rd_ptr_gray;
            rd_ptr_gray_sync_d2 <= rd_ptr_gray_sync_d1;
        end
    end

    // Write Full condition:
    // MSB and 2nd MSB of wr_ptr_gray and rd_ptr_gray_sync_d2 are opposite,
    // and the remaining bits are identical.
    assign wr_full = (wr_ptr_gray == {~rd_ptr_gray_sync_d2[ADDR_WIDTH:ADDR_WIDTH-1], rd_ptr_gray_sync_d2[ADDR_WIDTH-2:0]});

    // ----------------------------------------------------
    // Read Clock Domain Logic
    // ----------------------------------------------------

    // Binary and Gray Pointer increment
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= 0;
            rd_ptr_gray <= 0;
        end else if (rd_en && !rd_empty) begin
            rd_ptr_bin  <= rd_ptr_bin + 1'b1;
            rd_ptr_gray <= (rd_ptr_bin + 1'b1) ^ ((rd_ptr_bin + 1'b1) >> 1);
        end
    end

    // Read from memory (register data_out on rd_clk)
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            data_out <= 0;
        end else if (rd_en && !rd_empty) begin
            data_out <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
        end
    end

    // Synchronize Write Pointer (Gray) into Read Domain (2-stage D-FF)
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_sync_d1 <= 0;
            wr_ptr_gray_sync_d2 <= 0;
        end else begin
            wr_ptr_gray_sync_d1 <= wr_ptr_gray;
            wr_ptr_gray_sync_d2 <= wr_ptr_gray_sync_d1;
        end
    end

    // Read Empty condition:
    // Read pointer and synchronized write pointer are identical.
    assign rd_empty = (rd_ptr_gray == wr_ptr_gray_sync_d2);

endmodule
