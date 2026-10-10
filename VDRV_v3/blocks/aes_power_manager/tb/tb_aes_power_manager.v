`timescale 1ns/1ps

module tb_aes_power_manager;
    reg clk = 0;
    reg rst_n = 0;
    reg hw_direct_active = 0;
    reg hw_power_req = 0;
    reg aes_idle = 1;
    reg mem_valid = 0;
    reg [3:0] mem_wstrb = 0;
    reg [31:0] mem_wdata = 0;
    wire [31:0] mem_rdata;
    wire mem_ready;
    wire pd_aes_on;
    wire pd_aes_reset_n;
    wire aes_isolate;
    wire aes_quiesce_req;
    wire aes_power_ready;

    reg isolate = 1;
    wire [127:0] iso_data;
    wire iso_ready;
    wire iso_busy;
    wire [127:0] iso_prng;

    aes_power_manager u_dut (
        .clk(clk), .rst_n(rst_n), .hw_direct_active(hw_direct_active),
        .hw_power_req(hw_power_req), .aes_idle(aes_idle), .mem_valid(mem_valid),
        .mem_wstrb(mem_wstrb), .mem_wdata(mem_wdata), .mem_rdata(mem_rdata),
        .mem_ready(mem_ready), .pd_aes_on(pd_aes_on), .pd_aes_reset_n(pd_aes_reset_n),
        .aes_isolate(aes_isolate), .aes_quiesce_req(aes_quiesce_req),
        .aes_power_ready(aes_power_ready)
    );

    aes_isolation u_iso (
        .isolate(isolate), .aes_state_out_raw({128{1'bx}}), .aes_ready_raw(1'bx),
        .aes_busy_raw(1'bx), .prng_data_raw({128{1'bx}}), .aes_state_out(iso_data),
        .aes_ready(iso_ready), .aes_busy(iso_busy), .prng_data(iso_prng)
    );

    always #5 clk = ~clk;

    task write_power_req(input value);
        begin
            @(posedge clk);
            mem_valid <= 1'b1;
            mem_wstrb <= 4'hf;
            mem_wdata <= {31'b0, value};
            @(posedge clk);
            mem_valid <= 1'b0;
            mem_wstrb <= 4'b0;
        end
    endtask

    initial begin
        #20 rst_n = 1;
        #1;
        if (pd_aes_on !== 0 || aes_isolate !== 1) $fatal(1, "Reset must leave PD_AES off and isolated");

        write_power_req(1'b1);
        repeat (4) @(posedge clk);
        #1;
        if (aes_power_ready !== 1 || pd_aes_reset_n !== 1 || aes_isolate !== 0)
            $fatal(1, "Power-on sequence did not reach ON state");

        write_power_req(1'b0);
        repeat (3) @(posedge clk);
        #1;
        if (pd_aes_on !== 0 || aes_isolate !== 1)
            $fatal(1, "Power-off sequence did not reach OFF state");

        // Hardware-direct requests take precedence while the sequencer owns
        // the control interface.
        hw_direct_active = 1'b1;
        hw_power_req = 1'b1;
        repeat (4) @(posedge clk);
        #1;
        if (aes_power_ready !== 1) $fatal(1, "HW-direct ON request was not applied");
        hw_power_req = 1'b0;
        repeat (3) @(posedge clk);
        #1;
        if (pd_aes_on !== 0) $fatal(1, "HW-direct OFF request was not applied");
        hw_direct_active = 1'b0;

        if (iso_data !== 0 || iso_prng !== 0 || iso_ready !== 0 || iso_busy !== 0)
            $fatal(1, "Isolation did not clamp X-valued PD outputs");
        isolate = 0;
        #1;
        if (^iso_data !== 1'bx) $fatal(1, "Power-aware X model was not observable before isolation");

        $display("[UNIT TEST PASSED] aes_power_manager power sequencing and isolation");
        $finish;
    end
endmodule
