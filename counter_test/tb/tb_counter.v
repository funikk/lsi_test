// tb_counter.v
`timescale 1ns/1ps

module tb_counter;
    reg clk;
    reg rst_n;
    reg en;
    wire [7:0] count;

    // Instantiate Design Under Test (DUT)
    counter u_counter (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .count(count)
    );

    // Clock generation (50MHz -> 20ns period)
    always #10 clk = ~clk;

    initial begin
        // Waveform dumping setup
        $dumpfile("tb_counter.vcd");
        $dumpvars(0, tb_counter);

        // Initial states
        clk = 0;
        rst_n = 0;
        en = 0;

        // Release reset
        #40;
        rst_n = 1;
        
        // Enable counter
        #20;
        en = 1;

        // Let it run for some cycles
        #300;
        
        // Print final status and finish
        $display("Simulation finished. Final count value: %h", count);
        $finish;
    end
endmodule
