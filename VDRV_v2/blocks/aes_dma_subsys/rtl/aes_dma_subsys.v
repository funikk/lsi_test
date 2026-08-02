/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */

module aes_dma_subsys (
    input wire clk,
    input wire rst_n,

    // Hardware-direct load control from load_sequencer.  While active, this
    // takes ownership of load mode; otherwise the software MMIO setting is
    // used unchanged.
    input wire hw_load_mode_active,
    input wire hw_load_mode_en,
    input wire aes_power_ready,
    input wire aes_quiesce_req,
    input wire pd_aes_on,
    input wire pd_aes_reset_n,
    input wire aes_isolate,
    output wire aes_idle,

    // MMIO Slave Interface (from CPU)
    input wire mmio_valid,
    input wire [3:0] mmio_wstrb,
    input wire [31:0] mmio_addr,
    input wire [31:0] mmio_wdata,
    output reg [31:0] mmio_rdata,
    output reg mmio_ready,

    // DMA Master Interface (to DMEM Arbiter)
    output reg dma_valid,
    output reg [3:0] dma_wstrb,
    output reg [31:0] dma_addr,
    output reg [31:0] dma_wdata,
    input wire [31:0] dma_rdata,
    input wire dma_ready
);

    // MMIO Registers
    reg [31:0] reg_ctrl;        // 0x00
    reg [31:0] reg_status;      // 0x04
    reg [31:0] reg_key [0:3];   // 0x10 - 0x1C
    reg [31:0] reg_seed [0:3];  // 0x20 - 0x2C
    reg [31:0] reg_src_addr;    // 0x40
    reg [31:0] reg_dst_addr;    // 0x44
    reg [31:0] reg_len;         // 0x48

    // Internal Control Signals
    wire dma_start_request = mmio_valid && (mmio_wstrb != 4'b0) && (mmio_addr[7:0] == 8'h00) && mmio_wdata[0];
    wire dma_start_pulse   = dma_start_request && aes_power_ready && !aes_quiesce_req;
    wire dma_start_rejected = dma_start_request && (!aes_power_ready || aes_quiesce_req);
    wire sw_load_mode_en   = reg_ctrl[1];
    wire load_mode_request = hw_load_mode_active ? hw_load_mode_en : sw_load_mode_en;
    wire load_mode_en      = load_mode_request && aes_power_ready && !aes_quiesce_req;
    wire seed_load_pulse   = mmio_valid && (mmio_wstrb != 4'b0) && (mmio_addr[7:0] == 8'h00) && mmio_wdata[2] && aes_power_ready && !aes_quiesce_req;

    // AES/PRNG power-domain interface
    wire [127:0] prng_seed_128 = {reg_seed[3], reg_seed[2], reg_seed[1], reg_seed[0]};
    wire [127:0] prng_data_128;
    wire prng_en;
    reg aes_start;
    reg [127:0] aes_state_in;
    wire [127:0] aes_key_in = {reg_key[3], reg_key[2], reg_key[1], reg_key[0]};
    wire [127:0] aes_state_out;
    wire aes_ready;
    wire aes_busy;
    wire [127:0] aes_state_out_raw;
    wire aes_ready_raw;
    wire aes_busy_raw;
    wire [127:0] prng_data_raw;

    aes_prng_pd u_aes_prng_pd (
        .clk(clk),
        .pd_rst_n(pd_aes_reset_n),
        .pd_aes_on(pd_aes_on),
        .start(aes_start),
        .state_in(aes_state_in),
        .key_in(aes_key_in),
        .prng_en(prng_en),
        .load_seed(seed_load_pulse),
        .seed_in(prng_seed_128),
        .aes_state_out_raw(aes_state_out_raw),
        .aes_ready_raw(aes_ready_raw),
        .aes_busy_raw(aes_busy_raw),
        .prng_data_raw(prng_data_raw)
    );

    aes_isolation u_aes_isolation (
        .isolate(aes_isolate),
        .aes_state_out_raw(aes_state_out_raw),
        .aes_ready_raw(aes_ready_raw),
        .aes_busy_raw(aes_busy_raw),
        .prng_data_raw(prng_data_raw),
        .aes_state_out(aes_state_out),
        .aes_ready(aes_ready),
        .aes_busy(aes_busy),
        .prng_data(prng_data_128)
    );

    // AES Local Buffer (128-bit block buffer)
    reg [127:0] aes_in_buf;
    reg [127:0] aes_out_buf;

    // DMA State Machine
    localparam DMA_IDLE       = 3'd0;
    localparam DMA_READ_WORD  = 3'd1;
    localparam DMA_AES_START  = 3'd2;
    localparam DMA_AES_WAIT   = 3'd3;
    localparam DMA_WRITE_WORD = 3'd4;
    localparam DMA_DONE_ST    = 3'd5;

    reg [2:0] dma_state;
    reg [31:0] load_rem_blocks;
    reg        load_active;
    reg [1:0] word_cnt;
    reg [31:0] curr_src_addr;
    reg [31:0] curr_dst_addr;
    reg [31:0] rem_blocks;

    assign prng_en = load_mode_en ? (aes_ready || (dma_state == DMA_IDLE && !load_active)) : 1'b0;
    assign aes_idle = (dma_state == DMA_IDLE) && !dma_valid && !load_active && !aes_busy;

    // DMA and Mode Logic
    always @(posedge clk) begin
        if (!rst_n) begin
            dma_state       <= DMA_IDLE;
            dma_valid       <= 1'b0;
            dma_wstrb       <= 4'b0;
            dma_addr        <= 32'b0;
            dma_wdata       <= 32'b0;
            aes_start       <= 1'b0;
            aes_state_in    <= 128'b0;
            aes_in_buf      <= 128'b0;
            aes_out_buf     <= 128'b0;
            word_cnt        <= 2'b0;
            curr_src_addr   <= 32'b0;
            curr_dst_addr   <= 32'b0;
            rem_blocks      <= 32'b0;
            load_rem_blocks <= 32'b0;
            load_active     <= 1'b0;
            reg_status      <= 32'b0;
        end else begin
            // Status Update
            reg_status[0] <= (dma_state != DMA_IDLE);
            reg_status[2] <= !aes_ready && (dma_state == DMA_AES_WAIT || load_mode_en);
            reg_status[3] <= dma_start_rejected;

            if (load_mode_en) begin
                // PRNG High-Load Continuous / Finite Block Mode
                aes_state_in <= prng_data_128;

                if (!load_active) begin
                    load_active     <= 1'b1;
                    load_rem_blocks <= reg_len;
                    reg_status[1]   <= 1'b0; // Clear DONE flag
                    aes_start       <= 1'b1;
                end else if (aes_ready) begin
                    if (load_rem_blocks > 32'd0) begin
                        if (load_rem_blocks == 32'd1) begin
                            // Target block count reached -> auto-return to normal mode
                            reg_status[1] <= 1'b1; // Set DONE flag in STATUS
                            aes_start     <= 1'b0;
                            load_active   <= 1'b0;
                        end else begin
                            load_rem_blocks <= load_rem_blocks - 1'b1;
                            aes_start       <= 1'b1;
                        end
                    end else begin
                        // DMA_LEN == 0: Infinite load mode until CPU writes LOAD_MODE_EN = 0
                        aes_start <= 1'b1;
                    end
                end else begin
                    aes_start <= 1'b0;
                end
            end else begin
                load_active <= 1'b0;
                // DMA Mode State Machine
                case (dma_state)
                    DMA_IDLE: begin
                        aes_start <= 1'b0;
                        if (dma_start_pulse) begin
                            curr_src_addr <= reg_src_addr;
                            curr_dst_addr <= reg_dst_addr;
                            rem_blocks    <= reg_len;
                            word_cnt      <= 2'b0;
                            reg_status[1] <= 1'b0; // Clear DMA_DONE
                            if (reg_len > 0) begin
                                dma_state <= DMA_READ_WORD;
                            end else begin
                                reg_status[1] <= 1'b1;
                            end
                        end
                    end

                    DMA_READ_WORD: begin
                        // Request 32-bit word from DMEM
                        if (!dma_valid) begin
                            dma_valid <= 1'b1;
                            dma_wstrb <= 4'b0000;
                            dma_addr  <= curr_src_addr + {28'b0, word_cnt, 2'b00};
                        end else if (dma_ready) begin
                            dma_valid <= 1'b0;
                            case (word_cnt)
                                2'd0: aes_in_buf[ 31:  0] <= dma_rdata;
                                2'd1: aes_in_buf[ 63: 32] <= dma_rdata;
                                2'd2: aes_in_buf[ 95: 64] <= dma_rdata;
                                2'd3: aes_in_buf[127: 96] <= dma_rdata;
                            endcase

                            if (word_cnt == 2'd3) begin
                                word_cnt  <= 2'b0;
                                dma_state <= DMA_AES_START;
                            end else begin
                                word_cnt <= word_cnt + 1'b1;
                            end
                        end
                    end

                    DMA_AES_START: begin
                        aes_state_in <= aes_in_buf;
                        aes_start    <= 1'b1;
                        dma_state    <= DMA_AES_WAIT;
                    end

                    DMA_AES_WAIT: begin
                        aes_start <= 1'b0;
                        if (aes_ready) begin
                            aes_out_buf <= aes_state_out;
                            word_cnt    <= 2'b0;
                            dma_state   <= DMA_WRITE_WORD;
                        end
                    end

                    DMA_WRITE_WORD: begin
                        // Write 32-bit word to DMEM
                        if (!dma_valid) begin
                            dma_valid <= 1'b1;
                            dma_wstrb <= 4'b1111;
                            dma_addr  <= curr_dst_addr + {28'b0, word_cnt, 2'b00};
                            case (word_cnt)
                                2'd0: dma_wdata <= aes_out_buf[ 31:  0];
                                2'd1: dma_wdata <= aes_out_buf[ 63: 32];
                                2'd2: dma_wdata <= aes_out_buf[ 95: 64];
                                2'd3: dma_wdata <= aes_out_buf[127: 96];
                            endcase
                        end else if (dma_ready) begin
                            dma_valid <= 1'b0;
                            dma_wstrb <= 4'b0000;

                            if (word_cnt == 2'd3) begin
                                word_cnt      <= 2'b0;
                                curr_src_addr <= curr_src_addr + 32'd16;
                                curr_dst_addr <= curr_dst_addr + 32'd16;
                                rem_blocks    <= rem_blocks - 1'b1;

                                if (rem_blocks == 32'd1) begin
                                    dma_state <= DMA_DONE_ST;
                                end else begin
                                    dma_state <= DMA_READ_WORD;
                                end
                            end else begin
                                word_cnt <= word_cnt + 1'b1;
                            end
                        end
                    end

                    DMA_DONE_ST: begin
                        reg_status[1] <= 1'b1; // Set DMA_DONE
                        dma_state     <= DMA_IDLE;
                    end
                    default: dma_state <= DMA_IDLE;
                endcase
            end
        end
    end

    wire load_mode_auto_clear = load_mode_en && load_active && aes_ready && (load_rem_blocks == 32'd1);

    // MMIO Slave Read/Write Interface
    always @(posedge clk) begin
        if (!rst_n) begin
            mmio_ready   <= 1'b0;
            mmio_rdata   <= 32'b0;
            reg_ctrl     <= 32'b0;
            reg_key[0]   <= 32'h0; reg_key[1] <= 32'h0; reg_key[2] <= 32'h0; reg_key[3] <= 32'h0;
            reg_seed[0]  <= 32'hA5A5A5A5; reg_seed[1] <= 32'h5A5A5A5A;
            reg_seed[2]  <= 32'h01234567; reg_seed[3] <= 32'h89ABCDEF;
            reg_src_addr <= 32'b0;
            reg_dst_addr <= 32'b0;
            reg_len      <= 32'b0;
        end else begin
            mmio_ready <= mmio_valid;
            if (load_mode_auto_clear) begin
                reg_ctrl[1] <= 1'b0;
            end
            if (mmio_valid) begin
                if (mmio_wstrb != 4'b0) begin
                    // Write Logic
                    case (mmio_addr[7:0])
                        8'h00: reg_ctrl     <= mmio_wdata;
                        8'h10: reg_key[0]   <= mmio_wdata;
                        8'h14: reg_key[1]   <= mmio_wdata;
                        8'h18: reg_key[2]   <= mmio_wdata;
                        8'h1C: reg_key[3]   <= mmio_wdata;
                        8'h20: reg_seed[0]  <= mmio_wdata;
                        8'h24: reg_seed[1]  <= mmio_wdata;
                        8'h28: reg_seed[2]  <= mmio_wdata;
                        8'h2C: reg_seed[3]  <= mmio_wdata;
                        8'h40: reg_src_addr <= mmio_wdata;
                        8'h44: reg_dst_addr <= mmio_wdata;
                        8'h48: reg_len      <= mmio_wdata;
                        default: ;
                    endcase
                end else begin
                    // Read Logic
                    case (mmio_addr[7:0])
                        8'h00: mmio_rdata <= reg_ctrl;
                        8'h04: mmio_rdata <= reg_status;
                        8'h10: mmio_rdata <= reg_key[0];
                        8'h14: mmio_rdata <= reg_key[1];
                        8'h18: mmio_rdata <= reg_key[2];
                        8'h1C: mmio_rdata <= reg_key[3];
                        8'h20: mmio_rdata <= reg_seed[0];
                        8'h24: mmio_rdata <= reg_seed[1];
                        8'h28: mmio_rdata <= reg_seed[2];
                        8'h2C: mmio_rdata <= reg_seed[3];
                        8'h30: mmio_rdata <= prng_data_128[31:0];
                        8'h31, 8'h34: mmio_rdata <= prng_data_128[63:32];
                        8'h38: mmio_rdata <= prng_data_128[95:64];
                        8'h3C: mmio_rdata <= prng_data_128[127:96];
                        8'h40: mmio_rdata <= reg_src_addr;
                        8'h44: mmio_rdata <= reg_dst_addr;
                        8'h48: mmio_rdata <= reg_len;
                        default: mmio_rdata <= 32'b0;
                    endcase
                end
            end
        end
    end

endmodule
