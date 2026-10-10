module mac_array #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 16
)(
    input clk,
    input rst_n,
    input en,
    // Inputs at the edges: a flows horizontally, b flows vertically, c flows vertically
    input  [(ROWS*DATA_WIDTH)-1:0] a_in, // Left side
    input  [(COLS*DATA_WIDTH)-1:0] b_in, // Top side
    input  [(COLS*ACC_WIDTH)-1:0]  c_in, // Top side (initial partial sums)
    
    // Outputs at the edges
    output [(ROWS*DATA_WIDTH)-1:0] a_out, // Right side
    output [(COLS*DATA_WIDTH)-1:0] b_out, // Bottom side
    output [(COLS*ACC_WIDTH)-1:0]  mac_out // Bottom side (final results)
);

    // Internal wires connecting the units
    wire [DATA_WIDTH-1:0] a_wire [0:ROWS][0:COLS];
    wire [DATA_WIDTH-1:0] b_wire [0:ROWS][0:COLS];
    wire [ACC_WIDTH-1:0]  c_wire [0:ROWS][0:COLS];

    // Connect inputs
    genvar i, j;
    generate
        for (i = 0; i < ROWS; i = i + 1) begin : gen_row_in
            assign a_wire[i][0] = a_in[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH];
            assign a_out[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH] = a_wire[i][COLS];
        end
        for (j = 0; j < COLS; j = j + 1) begin : gen_col_in
            assign b_wire[0][j] = b_in[(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH];
            assign c_wire[0][j] = c_in[(j+1)*ACC_WIDTH-1 : j*ACC_WIDTH];
            
            assign b_out[(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH] = b_wire[ROWS][j];
            assign mac_out[(j+1)*ACC_WIDTH-1 : j*ACC_WIDTH] = c_wire[ROWS][j];
        end
    endgenerate

    // Instantiate MAC units
    generate
        for (i = 0; i < ROWS; i = i + 1) begin : row
            for (j = 0; j < COLS; j = j + 1) begin : col
                mac_unit #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) u_mac (
                    .clk(clk),
                    .rst_n(rst_n),
                    .en(en),
                    .a_in(a_wire[i][j]),
                    .b_in(b_wire[i][j]),
                    .c_in(c_wire[i][j]),
                    .a_out(a_wire[i][j+1]),
                    .b_out(b_wire[i+1][j]),
                    .mac_out(c_wire[i+1][j])
                );
            end
        end
    endgenerate

endmodule
