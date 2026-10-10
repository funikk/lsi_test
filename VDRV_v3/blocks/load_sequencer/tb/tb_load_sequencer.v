`timescale 1ns/1ps

module tb_load_sequencer;

    reg clk;
    reg rst_n;

    // UART Parser Interface
    reg        cmd_set_step;
    reg        cmd_start_seq;
    reg        cmd_stop_seq;
    reg [3:0]  step_id;
    reg [1:0]  step_state;
    reg [15:0] step_duration;

    // MMIO Slave Interface
    reg        mmio_valid;
    reg [7:0]  mmio_addr;
    reg [3:0]  mmio_wstrb;
    reg [31:0] mmio_wdata;
    wire [31:0] mmio_rdata;
    wire        mmio_ready;

    // Outputs
    wire       hw_direct_active;
    wire       running;
    wire       seq_done;
    wire       seq_pg_sync;
    wire [1:0] cur_profile_id;
    wire [7:0] cur_pd_req;
    wire [1:0] cur_marker;
    wire [2:0] cur_em_ctrl;
    wire [3:0] cur_step;
    wire       cpu_irq;

    // DUT instantiation
    load_sequencer u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_set_step(cmd_set_step),
        .cmd_start_seq(cmd_start_seq),
        .cmd_stop_seq(cmd_stop_seq),
        .step_id(step_id),
        .step_state(step_state),
        .step_duration(step_duration),
        .mmio_valid(mmio_valid),
        .mmio_addr(mmio_addr),
        .mmio_wstrb(mmio_wstrb),
        .mmio_wdata(mmio_wdata),
        .mmio_rdata(mmio_rdata),
        .mmio_ready(mmio_ready),
        .hw_direct_active(hw_direct_active),
        .running(running),
        .seq_done(seq_done),
        .seq_pg_sync(seq_pg_sync),
        .cur_profile_id(cur_profile_id),
        .cur_pd_req(cur_pd_req),
        .cur_marker(cur_marker),
        .cur_em_ctrl(cur_em_ctrl),
        .cur_step(cur_step),
        .cpu_irq(cpu_irq)
    );

    // Clock generator: 100MHz (10ns period)
    always #5 clk = ~clk;

    // Test failure helper
    integer error_count = 0;
    task fail(input [255:0] msg);
        begin
            $display("[ERROR @ %0t] %0s", $time, msg);
            error_count = error_count + 1;
            $display("TEST FAILED");
            $finish;
        end
    endtask

    // Watchdog timer (timeout after 50us = 5000 cycles)
    initial begin
        #50000;
        $display("[TIMEOUT] Watchdog timer expired!");
        $display("TEST FAILED");
        $finish;
    end

    // MMIO helper tasks
    task mmio_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            mmio_valid <= 1'b1;
            mmio_addr  <= addr;
            mmio_wstrb <= 4'hF;
            mmio_wdata <= data;
            @(posedge clk);
            while (!mmio_ready) @(posedge clk);
            mmio_valid <= 1'b0;
            mmio_wstrb <= 4'h0;
            mmio_wdata <= 32'h0;
        end
    endtask

    task mmio_read(input [7:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            mmio_valid <= 1'b1;
            mmio_addr  <= addr;
            mmio_wstrb <= 4'h0;
            mmio_wdata <= 32'h0;
            @(posedge clk);
            while (!mmio_ready) @(posedge clk);
            data = mmio_rdata;
            mmio_valid <= 1'b0;
        end
    endtask

    // UART helper tasks
    task uart_set_step(input [3:0] id, input [1:0] state, input [15:0] dur);
        begin
            @(posedge clk);
            cmd_set_step  <= 1'b1;
            step_id       <= id;
            step_state    <= state;
            step_duration <= dur;
            @(posedge clk);
            cmd_set_step  <= 1'b0;
        end
    endtask

    task uart_start;
        begin
            @(posedge clk);
            cmd_start_seq <= 1'b1;
            @(posedge clk);
            cmd_start_seq <= 1'b0;
        end
    endtask

    task uart_stop;
        begin
            @(posedge clk);
            cmd_stop_seq <= 1'b1;
            @(posedge clk);
            cmd_stop_seq <= 1'b0;
        end
    endtask

    // Variables for checks
    reg [31:0] rdata;
    integer c;
    integer pg_sync_count;
    integer irq_count;

    initial begin
        $dumpfile("sim/tb_load_sequencer.vcd");
        $dumpvars(0, tb_load_sequencer);

        // Initial values
        clk           = 0;
        rst_n         = 0;
        cmd_set_step  = 0;
        cmd_start_seq = 0;
        cmd_stop_seq  = 0;
        step_id       = 0;
        step_state    = 0;
        step_duration = 0;
        mmio_valid    = 0;
        mmio_addr     = 0;
        mmio_wstrb    = 0;
        mmio_wdata    = 0;

        #40;
        rst_n = 1;
        #20;

        $display("=== Phase 0: Reset State Verification ===");
        if (running !== 1'b0) fail("running not 0 at reset");
        if (seq_done !== 1'b0) fail("seq_done not 0 at reset");
        if (hw_direct_active !== 1'b0) fail("hw_direct_active not 0 at reset");
        if (seq_pg_sync !== 1'b0) fail("seq_pg_sync not 0 at reset");
        if (cpu_irq !== 1'b0) fail("cpu_irq not 0 at reset");
        if (cur_step !== 4'd0) fail("cur_step not 0 at reset");

        $display("=== Phase 1: MMIO Programming and Readback ===");
        // Step 0: DUR=2, PROFILE_ID=1, MARKER=2, EM_CTRL=3, PD_REQ=0xA5
        // W0[0] = (3 << 24) | (2 << 20) | (1 << 16) | 2 = 32'h0321_0002
        // W1[0] = 32'h0000_00A5
        mmio_write(8'h40, 32'h0321_0002);
        mmio_write(8'h44, 32'h0000_00A5);

        // Step 1: DUR=1, PROFILE_ID=2, MARKER=3, EM_CTRL=5, PD_REQ=0x5A
        // W0[1] = (5 << 24) | (3 << 20) | (2 << 16) | 1 = 32'h0532_0001
        // W1[1] = 32'h0000_005A
        mmio_write(8'h48, 32'h0532_0001);
        mmio_write(8'h4C, 32'h0000_005A);

        // Step 2: DUR=3, PROFILE_ID=3, MARKER=1, EM_CTRL=6, PD_REQ=0xFF
        // W0[2] = (6 << 24) | (1 << 20) | (3 << 16) | 3 = 32'h0613_0003
        // W1[2] = 32'h0000_00FF
        mmio_write(8'h50, 32'h0613_0003);
        mmio_write(8'h54, 32'h0000_00FF);

        // Readback and verify steps
        mmio_read(8'h40, rdata);
        if (rdata !== 32'h0321_0002) fail("Step 0 W0 mismatch");
        mmio_read(8'h44, rdata);
        if (rdata !== 32'h0000_00A5) fail("Step 0 W1 mismatch");

        mmio_read(8'h48, rdata);
        if (rdata !== 32'h0532_0001) fail("Step 1 W0 mismatch");
        mmio_read(8'h4C, rdata);
        if (rdata !== 32'h0000_005A) fail("Step 1 W1 mismatch");

        mmio_read(8'h50, rdata);
        if (rdata !== 32'h0613_0003) fail("Step 2 W0 mismatch");
        mmio_read(8'h54, rdata);
        if (rdata !== 32'h0000_00FF) fail("Step 2 W1 mismatch");

        // SEQ_CTRL: TICK_DIV=3, TOTAL_STEPS=2, ONESHOT=1, SEQ_ENABLE=0, IRQ_MODE=0
        // (3 << 16) | (2 << 4) | (1 << 2) | 0 = 32'h0003_0024
        mmio_write(8'h00, 32'h0003_0024);
        mmio_read(8'h00, rdata);
        if (rdata !== 32'h0003_0024) fail("SEQ_CTRL readback mismatch");

        // SEQ_STATUS readback
        mmio_read(8'h04, rdata);
        if (rdata !== 32'h0000_0000) fail("SEQ_STATUS readback not 0");

        // Unmapped address readback
        mmio_read(8'h10, rdata);
        if (rdata !== 32'h0000_0000) fail("Unmapped MMIO read not 0");

        $display("=== Phase 2: ONESHOT Run with Cycle-Accurate Verification ===");
        // Start via MMIO: TICK_DIV=3, TOTAL_STEPS=2, ONESHOT=1, SEQ_ENABLE=1, IRQ_MODE=0
        // 32'h0003_0026
        // Expected durations:
        // Step 0: (DUR+1)*(TICK_DIV+1) = (2+1)*(3+1) = 12 cycles
        // Step 1: (1+1)*(3+1) = 8 cycles
        // Step 2: (3+1)*(3+1) = 16 cycles
        // Total = 36 cycles until completion
        @(posedge clk);
        mmio_valid <= 1'b1;
        mmio_addr  <= 8'h00;
        mmio_wstrb <= 4'hF;
        mmio_wdata <= 32'h0003_0026;
        @(posedge clk);
        while (!mmio_ready) @(posedge clk);
        mmio_valid <= 1'b0;
        mmio_wstrb <= 4'h0;

        // Now in Cycle 1 of Step 0
        $display("[SIM] Step 0 starting at time %0t", $time);
        pg_sync_count = 0;
        for (c = 1; c <= 12; c = c + 1) begin
            if (running !== 1'b1) fail("running not 1 during Step 0");
            if (seq_done !== 1'b0) fail("seq_done not 0 during Step 0");
            if (hw_direct_active !== 1'b1) fail("hw_direct_active not 1 in direct mode Step 0");
            if (cur_step !== 4'd0) fail("cur_step not 0 during Step 0");
            if (cur_profile_id !== 2'd1) fail("cur_profile_id not 1 in Step 0");
            if (cur_marker !== 2'd2) fail("cur_marker not 2 in Step 0");
            if (cur_em_ctrl !== 3'd3) fail("cur_em_ctrl not 3 in Step 0");
            if (cur_pd_req !== 8'hA5) fail("cur_pd_req not 0xA5 in Step 0");
            if (cpu_irq !== 1'b0) fail("cpu_irq pulsed unexpectedly in Step 0");

            if (seq_pg_sync === 1'b1) pg_sync_count = pg_sync_count + 1;
            if (c == 1 && seq_pg_sync !== 1'b1) fail("seq_pg_sync did not pulse on cycle 1 of Step 0");
            if (c > 1 && seq_pg_sync !== 1'b0) fail("seq_pg_sync not 0 after cycle 1 of Step 0");

            @(posedge clk);
        end
        if (pg_sync_count !== 1) fail("seq_pg_sync did not pulse exactly once in Step 0");

        // Now in Cycle 1 of Step 1
        $display("[SIM] Step 1 starting at time %0t", $time);
        pg_sync_count = 0;
        for (c = 1; c <= 8; c = c + 1) begin
            if (running !== 1'b1) fail("running not 1 during Step 1");
            if (seq_done !== 1'b0) fail("seq_done not 0 during Step 1");
            if (hw_direct_active !== 1'b1) fail("hw_direct_active not 1 in direct mode Step 1");
            if (cur_step !== 4'd1) fail("cur_step not 1 during Step 1");
            if (cur_profile_id !== 2'd2) fail("cur_profile_id not 2 in Step 1");
            if (cur_marker !== 2'd3) fail("cur_marker not 3 in Step 1");
            if (cur_em_ctrl !== 3'd5) fail("cur_em_ctrl not 5 in Step 1");
            if (cur_pd_req !== 8'h5A) fail("cur_pd_req not 0x5A in Step 1");
            if (cpu_irq !== 1'b0) fail("cpu_irq pulsed unexpectedly in Step 1");

            if (seq_pg_sync === 1'b1) pg_sync_count = pg_sync_count + 1;
            if (c == 1 && seq_pg_sync !== 1'b1) fail("seq_pg_sync did not pulse on cycle 1 of Step 1");
            if (c > 1 && seq_pg_sync !== 1'b0) fail("seq_pg_sync not 0 after cycle 1 of Step 1");

            @(posedge clk);
        end
        if (pg_sync_count !== 1) fail("seq_pg_sync did not pulse exactly once in Step 1");

        // Now in Cycle 1 of Step 2
        $display("[SIM] Step 2 starting at time %0t", $time);
        pg_sync_count = 0;
        for (c = 1; c <= 16; c = c + 1) begin
            if (running !== 1'b1) fail("running not 1 during Step 2");
            if (seq_done !== 1'b0) fail("seq_done not 0 during Step 2");
            if (hw_direct_active !== 1'b1) fail("hw_direct_active not 1 in direct mode Step 2");
            if (cur_step !== 4'd2) fail("cur_step not 2 during Step 2");
            if (cur_profile_id !== 2'd3) fail("cur_profile_id not 3 in Step 2");
            if (cur_marker !== 2'd1) fail("cur_marker not 1 in Step 2");
            if (cur_em_ctrl !== 3'd6) fail("cur_em_ctrl not 6 in Step 2");
            if (cur_pd_req !== 8'hFF) fail("cur_pd_req not 0xFF in Step 2");
            if (cpu_irq !== 1'b0) fail("cpu_irq pulsed unexpectedly in Step 2");

            if (seq_pg_sync === 1'b1) pg_sync_count = pg_sync_count + 1;
            if (c == 1 && seq_pg_sync !== 1'b1) fail("seq_pg_sync did not pulse on cycle 1 of Step 2");
            if (c > 1 && seq_pg_sync !== 1'b0) fail("seq_pg_sync not 0 after cycle 1 of Step 2");

            @(posedge clk);
        end
        if (pg_sync_count !== 1) fail("seq_pg_sync did not pulse exactly once in Step 2");

        // Now in Completion State (Step 2 ended, ONESHOT=1)
        $display("[SIM] Sequence completed at time %0t", $time);
        for (c = 1; c <= 10; c = c + 1) begin
            if (running !== 1'b0) fail("running not cleared at end of ONESHOT sequence");
            if (seq_done !== 1'b1) fail("seq_done not set at end of ONESHOT sequence");
            if (hw_direct_active !== 1'b0) fail("hw_direct_active not 0 when stopped");
            if (seq_pg_sync !== 1'b0) fail("seq_pg_sync not 0 after sequence end");
            // Check outputs are held
            if (cur_step !== 4'd2) fail("cur_step not held at 2");
            if (cur_profile_id !== 2'd3) fail("cur_profile_id not held at 3");
            if (cur_marker !== 2'd1) fail("cur_marker not held at 1");
            if (cur_em_ctrl !== 3'd6) fail("cur_em_ctrl not held at 6");
            if (cur_pd_req !== 8'hFF) fail("cur_pd_req not held at 0xFF");
            @(posedge clk);
        end

        // MMIO check of SEQ_STATUS
        mmio_read(8'h04, rdata);
        if (rdata !== 32'h0000_0022) fail("SEQ_STATUS not 0x00000022 (step 2, seq_done=1, running=0)");

        $display("=== Phase 3: Loop Mode Verification (ONESHOT=0) ===");
        // Restart in Loop mode: TICK_DIV=3, TOTAL_STEPS=2, ONESHOT=0, SEQ_ENABLE=1, IRQ_MODE=0
        // (3 << 16) | (2 << 4) | (0 << 2) | (1 << 1) | 0 = 32'h0003_0022
        mmio_write(8'h00, 32'h0003_0022);

        // Check Step 0 starts, seq_done cleared, running set
        if (running !== 1'b1) fail("running not 1 at loop start");
        if (seq_done !== 1'b0) fail("seq_done not cleared on restart");
        if (cur_step !== 4'd0) fail("cur_step not 0 at start");
        if (seq_pg_sync !== 1'b1) fail("seq_pg_sync not pulsing on cycle 1 of loop step 0");

        // Step 0: 12 cycles
        for (c = 1; c <= 12; c = c + 1) begin
            if (cur_step !== 4'd0) fail("cur_step not 0 in loop step 0");
            @(posedge clk);
        end

        // Step 1: 8 cycles
        if (seq_pg_sync !== 1'b1) fail("seq_pg_sync not pulsing on cycle 1 of loop step 1");
        for (c = 1; c <= 8; c = c + 1) begin
            if (cur_step !== 4'd1) fail("cur_step not 1 in loop step 1");
            @(posedge clk);
        end

        // Step 2: 16 cycles
        if (seq_pg_sync !== 1'b1) fail("seq_pg_sync not pulsing on cycle 1 of loop step 2");
        for (c = 1; c <= 16; c = c + 1) begin
            if (cur_step !== 4'd2) fail("cur_step not 2 in loop step 2");
            @(posedge clk);
        end

        // Check wrap to Step 0!
        $display("[SIM] Checking loop wrap to Step 0 at time %0t", $time);
        if (running !== 1'b1) fail("running not 1 after loop wrap");
        if (seq_done !== 1'b0) fail("seq_done not 0 during loop wrap");
        if (cur_step !== 4'd0) fail("cur_step did not wrap to 0");
        if (cur_profile_id !== 2'd1) fail("cur_profile_id not Step 0 after wrap");
        if (seq_pg_sync !== 1'b1) fail("seq_pg_sync not pulsing on cycle 1 of wrapped step 0");

        $display("=== Phase 4: Stop via MMIO (SEQ_ENABLE=0) ===");
        // Stop sequencer while in Step 0
        @(posedge clk);
        mmio_write(8'h00, 32'h0003_0020);
        @(posedge clk);
        if (running !== 1'b0) fail("running not 0 after SEQ_ENABLE=0");
        mmio_read(8'h04, rdata);
        if (rdata[0] !== 1'b0) fail("SEQ_STATUS running bit not 0");

        $display("=== Phase 5: IRQ Mode Verification (IRQ_MODE=1) ===");
        // Configure IRQ_MODE=1, ONESHOT=1, TOTAL_STEPS=2, TICK_DIV=3, SEQ_ENABLE=1
        // (3 << 16) | (2 << 4) | (1 << 2) | (1 << 1) | 1 = 32'h0003_0027
        mmio_write(8'h00, 32'h0003_0027);

        // Start of Step 0: hw_direct_active MUST be 0
        if (hw_direct_active !== 1'b0) fail("hw_direct_active not 0 in IRQ_MODE");
        if (cpu_irq !== 1'b0) fail("cpu_irq pulsed at sequence start");

        // Wait through Step 0 (12 cycles)
        irq_count = 0;
        for (c = 1; c <= 11; c = c + 1) begin
            if (hw_direct_active !== 1'b0) fail("hw_direct_active not 0 during IRQ Step 0");
            if (cpu_irq !== 1'b0) fail("cpu_irq asserted prematurely during Step 0");
            @(posedge clk);
        end

        // End of Step 0: next cycle is Step 1 start, cpu_irq should pulse!
        @(posedge clk);
        if (cur_step !== 4'd1) fail("cur_step not 1 at transition");
        if (cpu_irq !== 1'b1) fail("cpu_irq did not pulse at Step 0 -> Step 1 transition");
        @(posedge clk);
        if (cpu_irq !== 1'b0) fail("cpu_irq did not deassert after 1 cycle");

        // Wait remaining cycles of Step 1 (total 8, already spent 2)
        for (c = 3; c <= 8; c = c + 1) begin
            if (hw_direct_active !== 1'b0) fail("hw_direct_active not 0 during IRQ Step 1");
            if (cpu_irq !== 1'b0) fail("cpu_irq asserted prematurely during Step 1");
            @(posedge clk);
        end

        // End of Step 1: next cycle is Step 2 start, cpu_irq should pulse!
        @(posedge clk);
        if (cur_step !== 4'd2) fail("cur_step not 2 at transition");
        if (cpu_irq !== 1'b1) fail("cpu_irq did not pulse at Step 1 -> Step 2 transition");
        @(posedge clk);
        if (cpu_irq !== 1'b0) fail("cpu_irq did not deassert after 1 cycle");

        // Wait remaining cycles of Step 2 (total 16, already spent 2)
        for (c = 3; c <= 16; c = c + 1) begin
            if (hw_direct_active !== 1'b0) fail("hw_direct_active not 0 during IRQ Step 2");
            if (cpu_irq !== 1'b0) fail("cpu_irq asserted prematurely during Step 2");
            @(posedge clk);
        end

        // End of Step 2: sequence completion transition! cpu_irq should pulse
        @(posedge clk);
        if (running !== 1'b0) fail("running not 0 at IRQ sequence end");
        if (seq_done !== 1'b1) fail("seq_done not 1 at IRQ sequence end");
        if (cpu_irq !== 1'b1) fail("cpu_irq did not pulse at sequence completion in IRQ_MODE");
        @(posedge clk);
        if (cpu_irq !== 1'b0) fail("cpu_irq did not deassert after completion pulse");

        $display("=== Phase 6: UART cmd_set_step & UART Start/Stop ===");
        // Step 1 currently has:
        // DUR=1, PROFILE_ID=2, MARKER=3, EM_CTRL=5, PD_REQ=0x5A
        // Update Step 1 via UART: step_state=0, step_duration=5
        uart_set_step(4'd1, 2'd0, 16'd5);

        // Readback Step 1 via MMIO:
        // W0[1]: DUR should be 5, PROFILE_ID should be 0, MARKER should still be 3, EM_CTRL should still be 5
        // Expected W0: (5 << 24) | (3 << 20) | (0 << 16) | 5 = 32'h0530_0005
        mmio_read(8'h48, rdata);
        if (rdata !== 32'h0530_0005) fail("UART cmd_set_step did not preserve MARKER/EM_CTRL or set DUR/PROFILE");

        // W1[1]: PD_REQ should still be 0x5A
        mmio_read(8'h4C, rdata);
        if (rdata !== 32'h0000_005A) fail("UART cmd_set_step corrupted PD_REQ");

        // Test UART start
        uart_start;
        @(posedge clk);
        if (running !== 1'b1) fail("UART cmd_start_seq failed to start sequencer");
        if (seq_done !== 1'b0) fail("UART cmd_start_seq failed to clear seq_done");
        if (cur_step !== 4'd0) fail("UART cmd_start_seq failed to reset cur_step to 0");

        #50;
        // Test UART stop
        uart_stop;
        @(posedge clk);
        if (running !== 1'b0) fail("UART cmd_stop_seq failed to stop sequencer");

        mmio_read(8'h04, rdata);
        if (rdata[0] !== 1'b0) fail("SEQ_STATUS shows running after UART stop");

        #100;
        $display("=== All tests completed successfully! ===");
        $display("TEST PASSED");
        $finish;
    end

endmodule
