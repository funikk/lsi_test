// tb_async_fifo.v
`timescale 1ns/1ps

module tb_async_fifo;
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4; // DEPTH = 16
    localparam DEPTH     = 1 << ADDR_WIDTH;

    // Signals
    reg                    wr_clk;
    reg                    wr_rst_n;
    reg                    wr_en;
    reg  [DATA_WIDTH-1:0]  data_in;
    wire                   wr_full;

    reg                    rd_clk;
    reg                    rd_rst_n;
    reg                    rd_en;
    wire [DATA_WIDTH-1:0]  data_out;
    wire                   rd_empty;

    // Instantiate DUT
`ifdef GATE_SIM
    async_fifo u_fifo (
        .wr_clk(wr_clk),
        .wr_rst_n(wr_rst_n),
        .wr_en(wr_en),
        .data_in(data_in),
        .wr_full(wr_full),
        .rd_clk(rd_clk),
        .rd_rst_n(rd_rst_n),
        .rd_en(rd_en),
        .data_out(data_out),
        .rd_empty(rd_empty)
    );
`else
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fifo (
        .wr_clk(wr_clk),
        .wr_rst_n(wr_rst_n),
        .wr_en(wr_en),
        .data_in(data_in),
        .wr_full(wr_full),
        .rd_clk(rd_clk),
        .rd_rst_n(rd_rst_n),
        .rd_en(rd_en),
        .data_out(data_out),
        .rd_empty(rd_empty)
    );
`endif

    // Clock generators
    // Write Clock: 100 MHz (10ns period)
    always #5 wr_clk = ~wr_clk;

    // Read Clock: 40 MHz (25ns period) - asymmetric to test CDC
    always #12.5 rd_clk = ~rd_clk;

    // Write Task
    task write_data(input [DATA_WIDTH-1:0] val);
        begin
            @(posedge wr_clk);
            #1;
            if (!wr_full) begin
                wr_en   = 1'b1;
                data_in = val;
            end else begin
                $display("[TB ERROR] Attempted to write to FULL FIFO!");
            end
            @(posedge wr_clk);
            #1;
            wr_en   = 1'b0;
        end
    endtask

    // Read Task
    task read_data;
        begin
            @(posedge rd_clk);
            #1;
            if (!rd_empty) begin
                rd_en = 1'b1;
            end else begin
                $display("[TB ERROR] Attempted to read from EMPTY FIFO!");
            end
            @(posedge rd_clk);
            #1;
            rd_en = 1'b0;
        end
    endtask

    integer i;

    initial begin
        // Waveform dumping
        $dumpfile("tb_async_fifo.vcd");
        $dumpvars(0, tb_async_fifo);

        // Initialization
        wr_clk   = 0;
        wr_rst_n = 0;
        wr_en    = 0;
        data_in  = 0;

        rd_clk   = 0;
        rd_rst_n = 0;
        rd_en    = 0;

        // Apply Reset
        #40;
        wr_rst_n = 1;
        rd_rst_n = 1;
        #20;

        $display("--- Starting Async FIFO Test ---");
        $display("Initial Flags: Full=%b, Empty=%b", wr_full, rd_empty);

        // 1. Write data until Full (DEPTH = 16)
        $display("Writing elements...");
        for (i = 0; i < DEPTH; i = i + 1) begin
            write_data(8'hD0 + i);
            $display("Written: %h, Full: %b", 8'hD0 + i, wr_full);
        end

        // Wait a few cycles for synchronization delay to propagate Full flag if needed
        #50;
        $display("Check Full flag: %b", wr_full);

        // Try writing to a full FIFO
        write_data(8'hFF);

        // 2. Read data until Empty
        $display("Reading elements...");
        while (!rd_empty) begin
            read_data();
            $display("Read out: %h, Empty: %b", data_out, rd_empty);
        end

        // Wait a few write cycles
        #100;
        $display("Final Flags: Full=%b, Empty=%b", wr_full, rd_empty);

        $display("--- Async FIFO Test Finished ---");
        $finish;
    end

endmodule
