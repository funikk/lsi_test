`timescale 1ns / 1ps

module tb_mac_array;

    // Parameters
    localparam ROWS = 2;
    localparam COLS = 2;
    localparam DATA_WIDTH = 8;
    localparam ACC_WIDTH = 16;
    
    // Derived widths
    localparam A_WIDTH = ROWS * DATA_WIDTH;
    localparam B_WIDTH = COLS * DATA_WIDTH;
    localparam C_WIDTH = COLS * ACC_WIDTH;

    // Testbench signals
    reg clk;
    reg rst_n;
    reg en;
    reg [A_WIDTH-1:0] a_in;
    reg [B_WIDTH-1:0] b_in;
    reg [C_WIDTH-1:0] c_in;
    
    wire [A_WIDTH-1:0] a_out;
    wire [B_WIDTH-1:0] b_out;
    wire [C_WIDTH-1:0] mac_out;

    // Instantiate the DUT
`ifdef GATE_SIM
    // During GLS, use standard instantiation
    mac_array dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .a_in(a_in),
        .b_in(b_in),
        .c_in(c_in),
        .a_out(a_out),
        .b_out(b_out),
        .mac_out(mac_out)
    );
`else
    mac_array #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .a_in(a_in),
        .b_in(b_in),
        .c_in(c_in),
        .a_out(a_out),
        .b_out(b_out),
        .mac_out(mac_out)
    );
`endif

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test sequence
    initial begin
        // Setup waveform dumping
        $dumpfile("tb_mac_array.vcd");
        $dumpvars(0, tb_mac_array);

        // Initialize inputs
        rst_n = 0;
        en = 0;
        a_in = 0;
        b_in = 0;
        c_in = 0;

        // Reset
        #20;
        rst_n = 1;
        
        // Cycle 1
        @(posedge clk);
        #1;
        en = 1;
        a_in = {8'd2, 8'd1}; // Row 1 = 2, Row 0 = 1
        b_in = {8'd4, 8'd3}; // Col 1 = 4, Col 0 = 3
        c_in = 0; // Initial partial sums are 0
        
        // Cycle 2
        @(posedge clk);
        #1;
        a_in = {8'd6, 8'd5};
        b_in = {8'd8, 8'd7};
        
        // Cycle 3
        @(posedge clk);
        #1;
        a_in = {8'd10, 8'd9};
        b_in = {8'd12, 8'd11};
        
        // Stop feeding data
        @(posedge clk);
        #1;
        en = 0;
        a_in = 0;
        b_in = 0;
        
        // Wait for pipeline to flush
        repeat(10) @(posedge clk);
        
        $display("Simulation complete.");
        $finish;
    end
endmodule
