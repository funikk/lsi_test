// tb_sync_fifo.v
`timescale 1ns/1ps

module tb_sync_fifo;
    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 8;
    parameter ALMOST_FULL_VAL  = 6;
    parameter ALMOST_EMPTY_VAL = 2;

    reg                    clk;
    reg                    rst_n;
    reg                    wr_en;
    reg                    rd_en;
    reg  [DATA_WIDTH-1:0]  data_in;
    wire [DATA_WIDTH-1:0]  data_out;
    wire                   full;
    wire                   empty;
    wire                   almost_full;
    wire                   almost_empty;
    wire [$clog2(DEPTH):0] data_count;

    // Instantiate FIFO
`ifdef GATE_SIM
    sync_fifo u_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty),
        .almost_full(almost_full),
        .almost_empty(almost_empty),
        .data_count(data_count)
    );
`else
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ALMOST_FULL_VAL(ALMOST_FULL_VAL),
        .ALMOST_EMPTY_VAL(ALMOST_EMPTY_VAL)
    ) u_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty),
        .almost_full(almost_full),
        .almost_empty(almost_empty),
        .data_count(data_count)
    );
`endif

    // Clock generation (50 MHz -> 20ns period)
    always #10 clk = ~clk;

    // Task for writing a byte
    task write_byte(input [DATA_WIDTH-1:0] val);
        begin
            @(posedge clk);
            #1; // Delay after clock edge
            wr_en   = 1'b1;
            data_in = val;
            @(posedge clk);
            #1;
            wr_en   = 1'b0;
        end
    endtask

    // Task for reading a byte
    task read_byte;
        begin
            @(posedge clk);
            #1;
            rd_en   = 1'b1;
            @(posedge clk);
            #1;
            rd_en   = 1'b0;
        end
    endtask

    initial begin
        // Waveform dumping setup
        $dumpfile("tb_sync_fifo.vcd");
        $dumpvars(0, tb_sync_fifo);

        // Initial states
        clk     = 0;
        rst_n   = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = 0;

        // Release reset
        #40;
        rst_n = 1;
        #20;

        $display("--- Starting FIFO Test ---");
        $display("Status: Empty=%b, Almost_Empty=%b", empty, almost_empty);

        // 1. Write data until Full
        $display("Writing data...");
        write_byte(8'hA1);
        write_byte(8'hB2);
        write_byte(8'hC3);
        write_byte(8'hD4);
        $display("Count: %d, Almost_Full: %b, Almost_Empty: %b", data_count, almost_full, almost_empty);
        write_byte(8'hE5);
        write_byte(8'hF6); // 6th element -> Should trigger almost_full
        $display("Count: %d, Almost_Full: %b", data_count, almost_full);
        write_byte(8'h77);
        write_byte(8'h88); // 8th element -> Should trigger full
        $display("Count: %d, Full: %b", data_count, full);

        // Try writing to a full FIFO
        write_byte(8'h99);

        // 2. Read data until Empty
        $display("Reading data...");
        read_byte();
        $display("Read Out: %h, Count: %d", data_out, data_count);
        read_byte();
        $display("Read Out: %h, Count: %d", data_out, data_count);
        read_byte();
        $display("Read Out: %h, Count: %d", data_out, data_count);
        read_byte();
        $display("Read Out: %h, Count: %d", data_out, data_count);
        read_byte();
        $display("Read Out: %h, Count: %d", data_out, data_count);
        read_byte();
        $display("Read Out: %h, Count: %d", data_out, data_count);
        read_byte();
        $display("Read Out: %h, Count: %d", data_out, data_count);
        read_byte();
        $display("Read Out: %h, Count: %d, Empty: %b", data_out, data_count, empty);

        // Try reading from empty FIFO
        read_byte();

        #100;
        $display("--- FIFO Test Finished ---");
        $finish;
    end

endmodule
