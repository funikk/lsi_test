module load_sequencer (
    input wire clk,
    input wire rst_n,

    // UART Parser Interface
    input wire cmd_set_step,
    input wire cmd_start_seq,
    input wire cmd_stop_seq,
    input wire [3:0] step_id,
    input wire [1:0] step_state,
    input wire [15:0] step_duration,

    /* verilator lint_off UNUSEDSIGNAL */
    input wire [31:0] mem_wdata,
    /* verilator lint_on UNUSEDSIGNAL */
    input wire [3:0]  mem_wstrb,
    input wire        mem_valid,
    input wire [31:0] mem_addr,
    output reg [31:0] mem_rdata,
    output reg        mem_ready,

    // Outputs
    output reg aes_load_mode_en,
    output wire hw_direct_active,
    output reg [1:0] cpu_load_state,
    output reg cpu_irq
);

    // Sequence memory
    reg [1:0] seq_state [0:15];
    reg [15:0] seq_duration [0:15];

    // Config Registers
    reg irq_mode;
    reg seq_enable;
    reg [3:0] total_steps;

    // Timer & Sequence state
    reg [5:0] tick_div; // max 50
    reg [15:0] duration_cnt;
    reg [3:0] current_step;
    reg running;

    // Identifies that the sequencer owns the direct load controls.  Keeping
    // this separate from aes_load_mode_en lets a consumer distinguish an
    // IDLE/CPU_FULL sequence step from an inactive sequencer.  In IRQ mode
    // the CPU retains ownership and changes AES mode through MMIO instead.
    assign hw_direct_active = running && !irq_mode;

    // MMIO Handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_mode <= 0;
            seq_enable <= 0;
            total_steps <= 4'hF;
            mem_ready <= 0;
            mem_rdata <= 0;
        end else begin
            mem_ready <= 0;
            if (mem_valid && !mem_ready) begin
                if (mem_addr[31:8] == 24'h8000_01) begin // Base 0x8000_0100
                    mem_ready <= 1'b1;
                    if (mem_wstrb != 0) begin
                        if (mem_addr[7:0] == 8'h00) begin
                            irq_mode <= mem_wdata[0];
                            seq_enable <= mem_wdata[1];
                            total_steps <= mem_wdata[7:4];
                        end
                    end else begin
                        if (mem_addr[7:0] == 8'h00) begin
                            mem_rdata <= {24'h0, total_steps, 2'b00, seq_enable, irq_mode};
                        end
                    end
                end
            end
        end
    end

    // Programming from UART
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<16; i=i+1) begin
                seq_state[i] <= 0;
                seq_duration[i] <= 0;
            end
        end else begin
            if (cmd_set_step) begin
                seq_state[step_id] <= step_state;
                seq_duration[step_id] <= step_duration;
            end
        end
    end

    // Sequencing Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_div <= 0;
            duration_cnt <= 0;
            current_step <= 0;
            running <= 0;
            aes_load_mode_en <= 0;
            cpu_load_state <= 0;
            cpu_irq <= 0;
        end else begin
            cpu_irq <= 0; // default pulse off
            if (cmd_start_seq || seq_enable) begin
                if (!running) begin
                    running <= 1;
                    current_step <= 0;
                    duration_cnt <= seq_duration[0];
                    tick_div <= 0;
                end
            end
            
            if (cmd_stop_seq || (!seq_enable && !cmd_start_seq && mem_valid && mem_addr[7:0]==8'h00 && mem_wstrb!=0 && mem_wdata[1]==0)) begin
                running <= 0;
                aes_load_mode_en <= 0;
                cpu_load_state <= 0;
            end

            if (running) begin
                // Update outputs based on current step state
                // 00=IDLE, 01=AES_FULL, 10=CPU_FULL, 11=BOTH_FULL
                aes_load_mode_en <= (seq_state[current_step] == 2'b01 || seq_state[current_step] == 2'b11);
                cpu_load_state <= seq_state[current_step];

                if (tick_div == 49) begin
                    tick_div <= 0;
                    if (duration_cnt == 0) begin
                        // Advance step
                        if (current_step == total_steps) begin
                            current_step <= 0;
                            duration_cnt <= seq_duration[0];
                        end else begin
                            current_step <= current_step + 1;
                            duration_cnt <= seq_duration[current_step + 1];
                        end
                        if (irq_mode) cpu_irq <= 1;
                    end else begin
                        duration_cnt <= duration_cnt - 1;
                    end
                end else begin
                    tick_div <= tick_div + 1;
                end
            end
        end
    end

endmodule
