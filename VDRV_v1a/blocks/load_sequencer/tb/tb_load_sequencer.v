`timescale 1ns/1ps

module tb_load_sequencer;

    reg clk;
    reg rst_n;

    reg cmd_set_step;
    reg cmd_start_seq;
    reg cmd_stop_seq;
    reg [3:0] step_id;
    reg [2:0] step_state;
    reg [15:0] step_duration;

    reg [31:0] mem_wdata;
    reg [3:0]  mem_wstrb;
    reg        mem_valid;
    reg [31:0] mem_addr;
    wire [31:0] mem_rdata;
    wire        mem_ready;

    wire       mac_load_mode_en;
    wire       crc_load_mode_en;
    wire       hw_direct_active;
    wire [2:0] cpu_load_state;
    wire       cpu_irq;

    integer errors = 0;

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
        .mac_load_mode_en(mac_load_mode_en),
        .crc_load_mode_en(crc_load_mode_en),
        .hw_direct_active(hw_direct_active),
        .cpu_load_state(cpu_load_state),
        .cpu_irq(cpu_irq)
    );

    initial clk = 0;
    always #5 clk = ~clk; // 100MHz (10ns period)

    task mmio_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            mem_valid <= 1'b1;
            mem_addr  <= addr;
            mem_wdata <= data;
            mem_wstrb <= 4'hF;
            @(posedge clk);
            while (!mem_ready) @(posedge clk);
            @(posedge clk);
            mem_valid <= 1'b0;
            mem_wstrb <= 4'h0;
        end
    endtask

    task mmio_read;
        input [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            mem_valid <= 1'b1;
            mem_addr  <= addr;
            mem_wstrb <= 4'h0;
            @(posedge clk);
            while (!mem_ready) @(posedge clk);
            data = mem_rdata;
            @(posedge clk);
            mem_valid <= 1'b0;
        end
    endtask

    task uart_program_step;
        input [3:0] id;
        input [2:0] state;
        input [15:0] duration;
        begin
            @(posedge clk);
            cmd_set_step   <= 1'b1;
            step_id        <= id;
            step_state     <= state;
            step_duration  <= duration;
            @(posedge clk);
            cmd_set_step   <= 1'b0;
            step_id        <= 4'd0;
            step_state     <= 3'd0;
            step_duration  <= 16'd0;
        end
    endtask

    reg [31:0] rdata;
    integer irq_count = 0;

    always @(posedge clk) begin
        if (cpu_irq) begin
            irq_count <= irq_count + 1;
        end
    end

    initial begin
        $dumpfile("tb_load_sequencer.vcd");
        $dumpvars(0, tb_load_sequencer);

        // Reset
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

        // Check initial state after reset
        if (mac_load_mode_en !== 1'b0 || crc_load_mode_en !== 1'b0 ||
            hw_direct_active !== 1'b0 || cpu_load_state !== 3'b000 || cpu_irq !== 1'b0) begin
            $display("FAIL: Initial outputs not zero after reset.");
            errors = errors + 1;
        end else begin
            $display("PASS: Initial reset state verified.");
        end

        // 1. Program sequence steps via UART
        $display("--- 1. Programming steps via UART ---");
        // Step 0: MAC_ONLY (3'b001), 2 ticks
        uart_program_step(4'd0, 3'b001, 16'd2);
        // Step 1: CRC_ONLY (3'b010), 2 ticks
        uart_program_step(4'd1, 3'b010, 16'd2);
        // Step 2: MAC_CRC  (3'b011), 2 ticks
        uart_program_step(4'd2, 3'b011, 16'd2);
        // Step 3: ALL_FULL (3'b111), 2 ticks
        uart_program_step(4'd3, 3'b111, 16'd2);

        // 2. MMIO Readback verification of STEP_REG (0x10, 0x14, 0x18, 0x1C)
        $display("--- 2. MMIO readback of STEP_REG ---");
        mmio_read(32'h8000_0110, rdata);
        if (rdata === {13'h0, 3'b001, 16'd2}) begin
            $display("PASS: MMIO STEP_REG[0] readback (0x10) = 0x%08x", rdata);
        end else begin
            $display("FAIL: MMIO STEP_REG[0] readback (0x10) expected 0x00010002, got 0x%08x", rdata);
            errors = errors + 1;
        end

        mmio_read(32'h8000_0114, rdata);
        if (rdata === {13'h0, 3'b010, 16'd2}) begin
            $display("PASS: MMIO STEP_REG[1] readback (0x14) = 0x%08x", rdata);
        end else begin
            $display("FAIL: MMIO STEP_REG[1] readback (0x14) expected 0x00020002, got 0x%08x", rdata);
            errors = errors + 1;
        end

        // 3. MMIO STEP_REG Write & Readback
        $display("--- 3. MMIO write and readback of STEP_REG[4] (0x20) ---");
        // Step 4: CPU_ONLY (3'b100), 5 ticks
        mmio_write(32'h8000_0120, {13'h0, 3'b100, 16'd5});
        mmio_read(32'h8000_0120, rdata);
        if (rdata === {13'h0, 3'b100, 16'd5}) begin
            $display("PASS: MMIO STEP_REG[4] (0x20) write/read verified: 0x%08x", rdata);
        end else begin
            $display("FAIL: MMIO STEP_REG[4] (0x20) expected 0x00040005, got 0x%08x", rdata);
            errors = errors + 1;
        end

        // 4. MMIO Readback of SEQ_CTRL (0x00), SEQ_STATUS (0x04), REG_LOAD_STATE (0x08)
        $display("--- 4. MMIO control and status readback before run ---");
        // Write SEQ_CTRL: total_steps=3, seq_enable=0, irq_mode=0 -> 32'h0000_0030
        mmio_write(32'h8000_0100, 32'h0000_0030);
        mmio_read(32'h8000_0100, rdata);
        if (rdata === 32'h0000_0030) begin
            $display("PASS: MMIO SEQ_CTRL readback (0x00) = 0x%08x", rdata);
        end else begin
            $display("FAIL: MMIO SEQ_CTRL readback expected 0x00000030, got 0x%08x", rdata);
            errors = errors + 1;
        end

        mmio_read(32'h8000_0108, rdata);
        if (rdata === 32'h0000_0000) begin
            $display("PASS: MMIO REG_LOAD_STATE readback (0x08) = 0x%08x", rdata);
        end else begin
            $display("FAIL: MMIO REG_LOAD_STATE readback expected 0, got 0x%08x", rdata);
            errors = errors + 1;
        end

        // 5. HW-Direct Mode Execution (irq_mode = 0)
        $display("--- 5. HW-Direct Mode Execution (irq_mode=0) ---");
        // Start sequence: total_steps=3, seq_enable=1, irq_mode=0 -> 32'h0000_0032
        mmio_write(32'h8000_0100, 32'h0000_0032);

        // Verify hw_direct_active asserted
        if (hw_direct_active !== 1'b1) begin
            $display("FAIL: hw_direct_active not asserted in HW-Direct mode.");
            errors = errors + 1;
        end else begin
            $display("PASS: hw_direct_active asserted correctly.");
        end

        // Step 0 check: MAC_ONLY (mac=1, crc=0, cpu_load_state=3'b001)
        if (mac_load_mode_en === 1'b1 && crc_load_mode_en === 1'b0 && cpu_load_state === 3'b001) begin
            $display("PASS: Step 0 outputs: mac_en=%b, crc_en=%b, cpu_load_state=%b",
                     mac_load_mode_en, crc_load_mode_en, cpu_load_state);
        end else begin
            $display("FAIL: Step 0 outputs incorrect: mac_en=%b, crc_en=%b, cpu_load_state=%b",
                     mac_load_mode_en, crc_load_mode_en, cpu_load_state);
            errors = errors + 1;
        end

        // Check SEQ_STATUS (0x04) during run
        mmio_read(32'h8000_0104, rdata);
        if (rdata[7] === 1'b1 && rdata[6:4] === 3'b001 && rdata[3:0] === 4'd0) begin
            $display("PASS: MMIO SEQ_STATUS (0x04) running=1, state=3'b001, step=0 (0x%08x)", rdata);
        end else begin
            $display("FAIL: MMIO SEQ_STATUS (0x04) expected running=1, state=001, step=0, got 0x%08x", rdata);
            errors = errors + 1;
        end

        // Check REG_LOAD_STATE (0x08)
        mmio_read(32'h8000_0108, rdata);
        if (rdata === 32'h0000_0001) begin
            $display("PASS: MMIO REG_LOAD_STATE (0x08) readback = 0x%08x", rdata);
        end else begin
            $display("FAIL: MMIO REG_LOAD_STATE expected 0x00000001, got 0x%08x", rdata);
            errors = errors + 1;
        end

        // Wait for Step 1: CRC_ONLY (mac=0, crc=1, cpu_load_state=3'b010)
        // Duration is 2 ticks (100 clock cycles = 1000ns)
        #1500;
        if (mac_load_mode_en === 1'b0 && crc_load_mode_en === 1'b1 && cpu_load_state === 3'b010) begin
            $display("PASS: Step 1 outputs: mac_en=%b, crc_en=%b, cpu_load_state=%b",
                     mac_load_mode_en, crc_load_mode_en, cpu_load_state);
        end else begin
            $display("FAIL: Step 1 outputs incorrect: mac_en=%b, crc_en=%b, cpu_load_state=%b",
                     mac_load_mode_en, crc_load_mode_en, cpu_load_state);
            errors = errors + 1;
        end

        // Wait for Step 2: MAC_CRC (mac=1, crc=1, cpu_load_state=3'b011)
        #1500;
        if (mac_load_mode_en === 1'b1 && crc_load_mode_en === 1'b1 && cpu_load_state === 3'b011) begin
            $display("PASS: Step 2 outputs: mac_en=%b, crc_en=%b, cpu_load_state=%b",
                     mac_load_mode_en, crc_load_mode_en, cpu_load_state);
        end else begin
            $display("FAIL: Step 2 outputs incorrect: mac_en=%b, crc_en=%b, cpu_load_state=%b",
                     mac_load_mode_en, crc_load_mode_en, cpu_load_state);
            errors = errors + 1;
        end

        // Wait for Step 3: ALL_FULL (mac=1, crc=1, cpu_load_state=3'b111)
        #1500;
        if (mac_load_mode_en === 1'b1 && crc_load_mode_en === 1'b1 && cpu_load_state === 3'b111) begin
            $display("PASS: Step 3 outputs: mac_en=%b, crc_en=%b, cpu_load_state=%b",
                     mac_load_mode_en, crc_load_mode_en, cpu_load_state);
        end else begin
            $display("FAIL: Step 3 outputs incorrect: mac_en=%b, crc_en=%b, cpu_load_state=%b",
                     mac_load_mode_en, crc_load_mode_en, cpu_load_state);
            errors = errors + 1;
        end

        // Verify cpu_irq was never asserted in HW-Direct mode
        if (irq_count !== 0) begin
            $display("FAIL: cpu_irq was asserted %0d times in HW-Direct mode.", irq_count);
            errors = errors + 1;
        end else begin
            $display("PASS: Zero cpu_irq events in HW-Direct mode verified.");
        end

        // Stop sequence via MMIO
        $display("--- 6. Stopping sequence via MMIO ---");
        mmio_write(32'h8000_0100, 32'h0000_0030); // seq_enable=0
        #100;
        if (mac_load_mode_en !== 1'b0 || crc_load_mode_en !== 1'b0 ||
            hw_direct_active !== 1'b0 || cpu_load_state !== 3'b000) begin
            $display("FAIL: Outputs not zero after sequence stop.");
            errors = errors + 1;
        end else begin
            $display("PASS: Sequencer stopped; outputs cleared.");
        end

        // 7. IRQ Mode & UART Start/Stop
        $display("--- 7. IRQ Mode and UART Start/Stop ---");
        irq_count = 0;
        // Configure: total_steps=1, seq_enable=0, irq_mode=1 -> 32'h0000_0011
        mmio_write(32'h8000_0100, 32'h0000_0011);

        // Start via UART command
        @(posedge clk);
        cmd_start_seq <= 1'b1;
        @(posedge clk);
        cmd_start_seq <= 1'b0;

        #50;
        // In IRQ mode, hw_direct_active must remain 0
        if (hw_direct_active !== 1'b0) begin
            $display("FAIL: hw_direct_active is asserted in IRQ mode.");
            errors = errors + 1;
        end else begin
            $display("PASS: hw_direct_active is correctly 0 in IRQ mode.");
        end

        // Wait across two step transitions (~3000ns)
        #4000;
        if (irq_count >= 2) begin
            $display("PASS: cpu_irq generated %0d interrupts as expected in IRQ mode.", irq_count);
        end else begin
            $display("FAIL: cpu_irq generated %0d interrupts (expected >= 2).", irq_count);
            errors = errors + 1;
        end

        // Stop via UART command
        @(posedge clk);
        cmd_stop_seq <= 1'b1;
        @(posedge clk);
        cmd_stop_seq <= 1'b0;
        #100;

        if (mac_load_mode_en !== 1'b0 || crc_load_mode_en !== 1'b0 ||
            hw_direct_active !== 1'b0 || cpu_load_state !== 3'b000) begin
            $display("FAIL: Outputs not zero after UART stop.");
            errors = errors + 1;
        end else begin
            $display("PASS: Sequencer stopped via UART; outputs cleared.");
        end

        #200;

        if (errors == 0) begin
            $display("============================================");
            $display("ALL LOAD_SEQUENCER TESTS PASSED (errors=%0d)", errors);
            $display("============================================");
        end else begin
            $display("============================================");
            $display("LOAD_SEQUENCER TESTS FAILED with %0d errors", errors);
            $display("============================================");
        end

        $finish;
    end

endmodule
