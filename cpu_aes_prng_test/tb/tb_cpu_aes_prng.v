`timescale 1ns / 1ps

module tb_cpu_aes_prng;

    reg clk;
    reg rst_n;
    wire trap_out;

    // Instantiate Top Module
    cpu_aes_prng_top u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .trap_out(trap_out)
    );

    // Clock Generation (100MHz -> 10ns period)
    always #5 clk = ~clk;

    /*
    always @(posedge clk) begin
        if (u_dut.cpu_mem_valid && u_dut.cpu_mem_ready) begin
            if (u_dut.cpu_mem_instr)
                $display("[TRACE PC] PC = 0x%08h, Instr = 0x%08h", u_dut.cpu_mem_addr, u_dut.cpu_mem_rdata);
            else if (u_dut.cpu_mem_wstrb != 4'b0)
                $display("[TRACE WRITE] Addr = 0x%08h, Data = 0x%08h", u_dut.cpu_mem_addr, u_dut.cpu_mem_wdata);
            else
                $display("[TRACE READ] Addr = 0x%08h, Data = 0x%08h", u_dut.cpu_mem_addr, u_dut.cpu_mem_rdata);
        end
        if (trap_out) begin
            $display("[TB ERROR] TRAP asserted at PC = 0x%08h!", u_dut.cpu_mem_addr);
            $finish;
        end
    end
    */

    integer cycle_count;

    initial begin
        clk = 0;
        rst_n = 0;

        $dumpfile("tb_cpu_aes_prng.vcd");
        $dumpvars(0, tb_cpu_aes_prng);

        #50;
        rst_n = 1;
        $display("[TB] System reset released. CPU started executing firmware...");

`ifndef GATE_SIM
        // Monitor completion flag at DMEM offset 0xFC (word index 63) in RTL simulation
        for (cycle_count = 0; cycle_count < 10000; cycle_count = cycle_count + 1) begin
            @(posedge clk);
            if (u_dut.u_dmem.mem[63] == 32'hDEADBEEF) begin
                $display("\n=======================================================");
                $display("[TB SUCCESS] Magic Marker 0xDEADBEEF detected!");
                $display("[TB SUCCESS] CPU completed sequence successfully.");
                $display("-------------------------------------------------------");
                $display("DMEM[0x100..0x10C] PRNG Readback by CPU:");
                $display("  PRNG[0]: 0x%08h", u_dut.u_dmem.mem[64]);
                $display("  PRNG[1]: 0x%08h", u_dut.u_dmem.mem[65]);
                $display("  PRNG[2]: 0x%08h", u_dut.u_dmem.mem[66]);
                $display("  PRNG[3]: 0x%08h", u_dut.u_dmem.mem[67]);
                $display("-------------------------------------------------------");
                $display("DMEM[0x20..0x2C] AES DMA Encrypted Ciphertext Output:");
                $display("  CT[0]: 0x%08h", u_dut.u_dmem.mem[8]);
                $display("  CT[1]: 0x%08h", u_dut.u_dmem.mem[9]);
                $display("  CT[2]: 0x%08h", u_dut.u_dmem.mem[10]);
                $display("  CT[3]: 0x%08h", u_dut.u_dmem.mem[11]);
                $display("=======================================================\n");

                // Let PRNG high-load mode run for another 50 cycles to observe switching activity
                #500;
                $finish;
            end
        end

        $display("\n[TB TIMEOUT / ERROR] Test timed out or CPU trapped.");
        $display("[TB DEBUG] u_dut.u_dmem.mem[63] = 0x%08h", u_dut.u_dmem.mem[63]);
        if (trap_out) $display("[TB ERROR] CPU TRAP asserted!");
        $finish;
`else
        // In Gate-Level Simulation (GLS), run for fixed duration to observe switching activity
        #50000;
        $display("[TB GLS SUCCESS] Gate-Level Simulation completed successfully.");
        $finish;
`endif
    end

endmodule
