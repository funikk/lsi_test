module load_sequencer (
    input wire clk,
    input wire rst_n,

    // UART Parser Interface
    input wire cmd_set_step,
    input wire cmd_start_seq,
    input wire cmd_stop_seq,
    input wire [3:0] step_id,
    input wire [2:0] step_state,
    input wire [15:0] step_duration,

    // MMIO Interface (Base 0x8000_0100)
    /* verilator lint_off UNUSEDSIGNAL */
    input wire [31:0] mem_wdata,
    input wire [3:0]  mem_wstrb,
    /* verilator lint_on UNUSEDSIGNAL */
    input wire        mem_valid,
    input wire [31:0] mem_addr,
    output reg [31:0] mem_rdata,
    output reg        mem_ready,

    // Outputs
    output reg        mac_load_mode_en,
    output reg        crc_load_mode_en,
    output wire       hw_direct_active,
    output reg [2:0]  cpu_load_state,
    output reg        cpu_irq
);

    // Sequence memory: 16 steps
    // 3-bit seq_state stores {cpu_en, crc_en, mac_en}
    reg [2:0] seq_state [0:15];
    reg [15:0] seq_duration [0:15];

    // Config Registers
    reg irq_mode;
    reg seq_enable;
    reg [3:0] total_steps;

    // Timer & Sequence state
    reg [5:0] tick_div; // counts 0 to 49 (50 cycles = 0.5us at 100MHz)
    reg [15:0] duration_cnt;
    reg [3:0] current_step;
    reg running;

    // Identifies that the sequencer owns the direct load controls.
    // In IRQ mode the CPU retains ownership and changes mode through MMIO instead.
    assign hw_direct_active = running && !irq_mode;

    // MMIO Address Decoding
    wire mmio_sel = mem_valid && !mem_ready && (mem_addr[31:8] == 24'h8000_01);
    wire mmio_ctrl_wr = mmio_sel && (mem_addr[7:0] == 8'h00) && (mem_wstrb != 4'h0);
    wire mmio_step_wr = mmio_sel && (mem_addr[7:0] >= 8'h10) && (mem_addr[7:0] <= 8'h4C) && (mem_wstrb != 4'h0);
    /* verilator lint_off UNUSEDSIGNAL */
    wire [7:0] mmio_step_diff = (mem_addr[7:0] - 8'h10) >> 2;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [3:0] mmio_step_idx = mmio_step_diff[3:0];

    // MMIO Read & Ready Handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b0;
            mem_rdata <= 32'd0;
        end else begin
            mem_ready <= 1'b0;
            if (mmio_sel) begin
                mem_ready <= 1'b1;
                case (mem_addr[7:0])
                    8'h00: begin
                        mem_rdata <= {24'h0, total_steps, 2'b00, seq_enable, irq_mode};
                    end
                    8'h04: begin
                        mem_rdata <= {duration_cnt, 8'h00, running, seq_state[current_step], current_step};
                    end
                    8'h08: begin
                        mem_rdata <= {29'h0, cpu_load_state};
                    end
                    default: begin
                        if (mem_addr[7:0] >= 8'h10 && mem_addr[7:0] <= 8'h4C) begin
                            mem_rdata <= {13'h0, seq_state[mmio_step_idx], seq_duration[mmio_step_idx]};
                        end else begin
                            mem_rdata <= 32'd0;
                        end
                    end
                endcase
            end
        end
    end

    // Programming Sequence Memory (UART or MMIO)
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                seq_state[i] <= 3'd0;
                seq_duration[i] <= 16'd0;
            end
        end else begin
            if (cmd_set_step) begin
                seq_state[step_id] <= step_state;
                seq_duration[step_id] <= step_duration;
            end else if (mmio_step_wr) begin
                seq_state[mmio_step_idx] <= mem_wdata[18:16];
                seq_duration[mmio_step_idx] <= mem_wdata[15:0];
            end
        end
    end

    // Sequence Start / Stop Conditions
    wire start_req = cmd_start_seq || (mmio_ctrl_wr && mem_wdata[1]);
    wire stop_req  = cmd_stop_seq  || (mmio_ctrl_wr && !mem_wdata[1]);

    // Sequencing Execution Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_mode <= 1'b0;
            seq_enable <= 1'b0;
            total_steps <= 4'hF;
            running <= 1'b0;
            current_step <= 4'd0;
            duration_cnt <= 16'd0;
            tick_div <= 6'd0;
            mac_load_mode_en <= 1'b0;
            crc_load_mode_en <= 1'b0;
            cpu_load_state <= 3'b000;
            cpu_irq <= 1'b0;
        end else begin
            cpu_irq <= 1'b0; // Default single-cycle pulse

            if (mmio_ctrl_wr) begin
                irq_mode <= mem_wdata[0];
                seq_enable <= mem_wdata[1];
                total_steps <= mem_wdata[7:4];
            end

            if (stop_req) begin
                running <= 1'b0;
                seq_enable <= 1'b0;
                mac_load_mode_en <= 1'b0;
                crc_load_mode_en <= 1'b0;
                cpu_load_state <= 3'b000;
            end else if (start_req) begin
                running <= 1'b1;
                seq_enable <= 1'b1;
                current_step <= 4'd0;
                duration_cnt <= seq_duration[0];
                tick_div <= 6'd0;
                mac_load_mode_en <= seq_state[0][0];
                crc_load_mode_en <= seq_state[0][1];
                cpu_load_state   <= seq_state[0];
            end else if (running) begin
                mac_load_mode_en <= seq_state[current_step][0];
                crc_load_mode_en <= seq_state[current_step][1];
                cpu_load_state   <= seq_state[current_step];

                if (tick_div == 6'd49) begin
                    tick_div <= 6'd0;
                    if (duration_cnt == 16'd0) begin
                        if (current_step == total_steps) begin
                            current_step <= 4'd0;
                            duration_cnt <= seq_duration[0];
                            mac_load_mode_en <= seq_state[0][0];
                            crc_load_mode_en <= seq_state[0][1];
                            cpu_load_state   <= seq_state[0];
                        end else begin
                            current_step <= current_step + 4'd1;
                            duration_cnt <= seq_duration[current_step + 4'd1];
                            mac_load_mode_en <= seq_state[current_step + 4'd1][0];
                            crc_load_mode_en <= seq_state[current_step + 4'd1][1];
                            cpu_load_state   <= seq_state[current_step + 4'd1];
                        end
                        if (irq_mode) cpu_irq <= 1'b1;
                    end else begin
                        duration_cnt <= duration_cnt - 16'd1;
                    end
                end else begin
                    tick_div <= tick_div + 6'd1;
                end
            end
        end
    end

endmodule
