`timescale 1ns/1ps

module load_sequencer (
    input  wire        clk,
    input  wire        rst_n,

    // UART Parser Interface
    input  wire        cmd_set_step,
    input  wire        cmd_start_seq,
    input  wire        cmd_stop_seq,
    input  wire [3:0]  step_id,
    input  wire [1:0]  step_state,
    input  wire [15:0] step_duration,

    // MMIO Slave Interface
    input  wire        mmio_valid,
    input  wire [7:0]  mmio_addr,
    input  wire [3:0]  mmio_wstrb,
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [31:0] mmio_wdata,
    /* verilator lint_on UNUSEDSIGNAL */
    output reg  [31:0] mmio_rdata,
    output reg         mmio_ready,

    // Outputs
    output wire        hw_direct_active,
    output reg         running,
    output reg         seq_done,
    output reg         seq_pg_sync,
    output reg  [1:0]  cur_profile_id,
    output reg  [7:0]  cur_pd_req,
    output reg  [1:0]  cur_marker,
    output reg  [2:0]  cur_em_ctrl,
    output reg  [3:0]  cur_step,
    output reg         cpu_irq
);

    // Sequence memory tables (up to 16 steps)
    reg [15:0] seq_duration   [0:15];
    reg [1:0]  seq_profile_id [0:15];
    reg [1:0]  seq_marker     [0:15];
    reg [2:0]  seq_em_ctrl    [0:15];
    reg [7:0]  seq_pd_req     [0:15];

    // Config Registers
    reg        irq_mode;
    reg        seq_enable;
    reg        oneshot;
    reg [3:0]  total_steps;
    reg [15:0] tick_div;

    // Counters
    reg [15:0] tick_cnt;
    reg [15:0] dur_cnt;

    // Address decode
    wire is_step_addr = (mmio_addr >= 8'h40) && (mmio_addr <= 8'hBC) && (mmio_addr[1:0] == 2'b00);
    /* verilator lint_off UNUSEDSIGNAL */
    wire [7:0] step_offset = mmio_addr - 8'h40;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [3:0] step_idx = step_offset[6:3];
    wire is_step_w1 = step_offset[2];

    wire mmio_write = mmio_valid && !mmio_ready && (mmio_wstrb != 4'b0000);
    wire mmio_write_seq_ctrl = mmio_write && (mmio_addr == 8'h00);
    wire mmio_write_w0 = mmio_write && is_step_addr && !is_step_w1;
    wire mmio_write_w1 = mmio_write && is_step_addr && is_step_w1;

    // Direct HW ownership active when running in direct (non-IRQ) mode
    assign hw_direct_active = running && !irq_mode;

    // Start/Stop triggers
    wire start_seq = (mmio_write_seq_ctrl && mmio_wdata[1] && (!seq_enable || !running)) || cmd_start_seq;
    wire stop_seq  = (mmio_write_seq_ctrl && !mmio_wdata[1]) || cmd_stop_seq;

    // MMIO Read & Ready Handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mmio_ready <= 1'b0;
            mmio_rdata <= 32'h0;
        end else begin
            mmio_ready <= 1'b0;
            if (mmio_valid && !mmio_ready) begin
                mmio_ready <= 1'b1;
                if (mmio_wstrb == 4'b0000) begin
                    if (mmio_addr == 8'h00) begin
                        mmio_rdata <= {tick_div, 8'h00, total_steps, 1'b0, oneshot, seq_enable, irq_mode};
                    end else if (mmio_addr == 8'h04) begin
                        mmio_rdata <= {24'h00_0000, cur_step, 2'b00, seq_done, running};
                    end else if (is_step_addr) begin
                        if (!is_step_w1) begin
                            mmio_rdata <= {5'b0, seq_em_ctrl[step_idx], 2'b0, seq_marker[step_idx], 2'b0, seq_profile_id[step_idx], seq_duration[step_idx]};
                        end else begin
                            mmio_rdata <= {24'h00_0000, seq_pd_req[step_idx]};
                        end
                    end else begin
                        mmio_rdata <= 32'h0;
                    end
                end
            end
        end
    end

    // Configuration Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_mode    <= 1'b0;
            seq_enable  <= 1'b0;
            oneshot     <= 1'b0;
            total_steps <= 4'h0;
            tick_div    <= 16'd49;
        end else begin
            if (mmio_write_seq_ctrl) begin
                irq_mode    <= mmio_wdata[0];
                seq_enable  <= mmio_wdata[1];
                oneshot     <= mmio_wdata[2];
                total_steps <= mmio_wdata[7:4];
                tick_div    <= mmio_wdata[31:16];
            end else if (cmd_start_seq) begin
                seq_enable  <= 1'b1;
            end else if (cmd_stop_seq) begin
                seq_enable  <= 1'b0;
            end
        end
    end

    // Step Memory Programming (MMIO and UART)
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                seq_duration[i]   <= 16'd0;
                seq_profile_id[i] <= 2'd0;
                seq_marker[i]     <= 2'd0;
                seq_em_ctrl[i]    <= 3'd0;
                seq_pd_req[i]     <= 8'd0;
            end
        end else begin
            for (i = 0; i < 16; i = i + 1) begin
                if (mmio_write_w0 && (step_idx == i[3:0])) begin
                    seq_duration[i]   <= mmio_wdata[15:0];
                    seq_profile_id[i] <= mmio_wdata[17:16];
                    seq_marker[i]     <= mmio_wdata[21:20];
                    seq_em_ctrl[i]    <= mmio_wdata[26:24];
                end else if (cmd_set_step && (step_id == i[3:0])) begin
                    seq_duration[i]   <= step_duration;
                    seq_profile_id[i] <= step_state;
                end

                if (mmio_write_w1 && (step_idx == i[3:0])) begin
                    seq_pd_req[i] <= mmio_wdata[7:0];
                end
            end
        end
    end

    // Sequence Execution FSM & Counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running        <= 1'b0;
            seq_done       <= 1'b0;
            seq_pg_sync    <= 1'b0;
            cur_profile_id <= 2'd0;
            cur_pd_req     <= 8'd0;
            cur_marker     <= 2'd0;
            cur_em_ctrl    <= 3'd0;
            cur_step       <= 4'd0;
            cpu_irq        <= 1'b0;
            tick_cnt       <= 16'd0;
            dur_cnt        <= 16'd0;
        end else begin
            seq_pg_sync <= 1'b0;
            cpu_irq     <= 1'b0;

            if (stop_seq) begin
                running     <= 1'b0;
                seq_pg_sync <= 1'b0;
                cpu_irq     <= 1'b0;
            end else if (start_seq) begin
                running        <= 1'b1;
                seq_done       <= 1'b0;
                cur_step       <= 4'd0;
                cur_profile_id <= (cmd_set_step && (step_id == 4'd0)) ? step_state : seq_profile_id[0];
                cur_pd_req     <= seq_pd_req[0];
                cur_marker     <= seq_marker[0];
                cur_em_ctrl    <= seq_em_ctrl[0];
                dur_cnt        <= (cmd_set_step && (step_id == 4'd0)) ? step_duration : seq_duration[0];
                tick_cnt       <= 16'd0;
                seq_pg_sync    <= 1'b1;
                cpu_irq        <= 1'b0;
            end else if (running) begin
                if (tick_cnt == tick_div) begin
                    tick_cnt <= 16'd0;
                    if (dur_cnt == 16'd0) begin
                        if (cur_step == total_steps) begin
                            if (oneshot) begin
                                running     <= 1'b0;
                                seq_done    <= 1'b1;
                                seq_pg_sync <= 1'b0;
                                if (irq_mode) cpu_irq <= 1'b1;
                            end else begin
                                cur_step       <= 4'd0;
                                cur_profile_id <= seq_profile_id[0];
                                cur_pd_req     <= seq_pd_req[0];
                                cur_marker     <= seq_marker[0];
                                cur_em_ctrl    <= seq_em_ctrl[0];
                                dur_cnt        <= seq_duration[0];
                                seq_pg_sync    <= 1'b1;
                                if (irq_mode) cpu_irq <= 1'b1;
                            end
                        end else begin
                            cur_step       <= cur_step + 4'd1;
                            cur_profile_id <= seq_profile_id[cur_step + 4'd1];
                            cur_pd_req     <= seq_pd_req[cur_step + 4'd1];
                            cur_marker     <= seq_marker[cur_step + 4'd1];
                            cur_em_ctrl    <= seq_em_ctrl[cur_step + 4'd1];
                            dur_cnt        <= seq_duration[cur_step + 4'd1];
                            seq_pg_sync    <= 1'b1;
                            if (irq_mode) cpu_irq <= 1'b1;
                        end
                    end else begin
                        dur_cnt <= dur_cnt - 16'd1;
                    end
                end else begin
                    tick_cnt <= tick_cnt + 16'd1;
                end
            end
        end
    end

endmodule
