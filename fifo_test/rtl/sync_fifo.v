// sync_fifo.v
// Parameterized Synchronous FIFO Memory Buffer
module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ALMOST_FULL_VAL  = 12,
    parameter ALMOST_EMPTY_VAL = 4
) (
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    wr_en,
    input  wire                    rd_en,
    input  wire [DATA_WIDTH-1:0]   data_in,
    output reg  [DATA_WIDTH-1:0]   data_out,
    output wire                    full,
    output wire                    empty,
    output reg                     almost_full,
    output reg                     almost_empty,
    output reg  [$clog2(DEPTH):0]  data_count
);

    // Local parameters
    localparam ADDR_WIDTH = $clog2(DEPTH);
    /* verilator lint_off WIDTHTRUNC */
    localparam [ADDR_WIDTH-1:0] MAX_ADDR = DEPTH - 1;
    /* verilator lint_on WIDTHTRUNC */

    // Internal memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Read and write pointers
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    // Status flags logic
    assign full  = (data_count == DEPTH);
    assign empty = (data_count == 0);

    // Write operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {ADDR_WIDTH{1'b0}};
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= data_in;
            if (wr_ptr == MAX_ADDR) begin
                wr_ptr <= {ADDR_WIDTH{1'b0}};
            end else begin
                wr_ptr <= wr_ptr + 1'b1;
            end
        end
    end

    // Read operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr   <= {ADDR_WIDTH{1'b0}};
            data_out <= {DATA_WIDTH{1'b0}};
        end else if (rd_en && !empty) begin
            data_out <= mem[rd_ptr];
            if (rd_ptr == MAX_ADDR) begin
                rd_ptr <= {ADDR_WIDTH{1'b0}};
            end else begin
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

    // Data counter logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_count   <= 0;
            almost_full  <= 1'b0;
            almost_empty <= 1'b1;
        end else begin
            // Update counter
            case ({wr_en && !full, rd_en && !empty})
                2'b10: data_count <= data_count + 1'b1;
                2'b01: data_count <= data_count - 1'b1;
                default: data_count <= data_count; // 00 or 11 (no change)
            endcase

            // Generate almost flags based on updated count
            if (wr_en && !full && !(rd_en && !empty)) begin
                almost_full  <= (data_count + 1'b1 >= ALMOST_FULL_VAL);
                almost_empty <= (data_count + 1'b1 <= ALMOST_EMPTY_VAL);
            end else if (rd_en && !empty && !(wr_en && !full)) begin
                almost_full  <= (data_count - 1'b1 >= ALMOST_FULL_VAL);
                almost_empty <= (data_count - 1'b1 <= ALMOST_EMPTY_VAL);
            end else begin
                almost_full  <= (data_count >= ALMOST_FULL_VAL);
                almost_empty <= (data_count <= ALMOST_EMPTY_VAL);
            end
        end
    end

endmodule
