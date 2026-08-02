`timescale 1ns/1ps

module tb_load_sequencer;
    reg clk;
    reg rst_n;

    reg cmd_set_step;
    reg cmd_start_seq;
    reg cmd_stop_seq;
    reg [3:0] step_id;
    reg [1:0] step_state;
    reg [15:0] step_duration;

    reg [31:0] mem_wdata;
    reg [3:0] mem_wstrb;
    reg mem_valid;
    reg [31:0] mem_addr;
    wire [31:0] mem_rdata;
    wire mem_ready;

    wire aes_load_mode_en;
    wire [1:0] cpu_load_state;
    wire cpu_irq;

    load_sequencer u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_set_step(cmd_set_step),
        .cmd_start_seq(cmd_start_seq),
        .cmd_stop_seq(cmd_stop_seq),
        .step_id(step_id),
        .step_state(step_state),
        .step_duration(step_duration),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_valid(mem_valid),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready),
        .aes_load_mode_en(aes_load_mode_en),
        .cpu_load_state(cpu_load_state),
        .cpu_irq(cpu_irq)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_load_sequencer.vcd");
        $dumpvars(0, tb_load_sequencer);

        rst_n = 0;
        cmd_set_step = 0;
        cmd_start_seq = 0;
        cmd_stop_seq = 0;
        step_id = 0;
        step_state = 0;
        step_duration = 0;
        mem_wdata = 0;
        mem_wstrb = 0;
        mem_valid = 0;
        mem_addr = 0;
        #100;
        rst_n = 1;
        #100;

        // program step 0
        @(posedge clk);
        cmd_set_step <= 1;
        step_id <= 0;
        step_state <= 2'b01; // AES_FULL
        step_duration <= 2; // 2 ticks = 1us
        @(posedge clk);
        cmd_set_step <= 0;

        // program step 1
        @(posedge clk);
        cmd_set_step <= 1;
        step_id <= 1;
        step_state <= 2'b10; // CPU_FULL
        step_duration <= 2;
        @(posedge clk);
        cmd_set_step <= 0;

        // config total_steps=1, seq_enable=1, irq_mode=1
        @(posedge clk);
        mem_valid <= 1;
        mem_addr <= 32'h8000_0100;
        mem_wstrb <= 4'hF;
        mem_wdata <= {24'h0, 4'h1, 2'b00, 1'b1, 1'b1};
        @(posedge clk);
        while (!mem_ready) @(posedge clk);
        mem_valid <= 0;
        mem_wstrb <= 0;

        // wait for sequence to start and run
        #10000;
        $finish;
    end
endmodule
