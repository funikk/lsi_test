/* verilator lint_off MULTITOP */
/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */

module load_dma_subsys (
    input  wire        clk,
    input  wire        rst_n,

    // Hardware-direct load control from load_sequencer
    input  wire        hw_load_mode_active,
    input  wire        hw_mac_load_en,
    input  wire        hw_crc_load_en,

    // MMIO Slave Interface (from CPU, 0x8000_0000 - 0x8000_0048)
    input  wire        mmio_valid,
    input  wire [3:0]  mmio_wstrb,
    input  wire [31:0] mmio_addr,
    input  wire [31:0] mmio_wdata,
    output reg  [31:0] mmio_rdata,
    output reg         mmio_ready,

    // DMA Master Interface (to DMEM Arbiter)
    output reg         dma_valid,
    output reg  [3:0]  dma_wstrb,
    output reg  [31:0] dma_addr,
    output reg  [31:0] dma_wdata,
    input  wire [31:0] dma_rdata,
    input  wire        dma_ready
);

    // MMIO Registers
    reg [31:0] reg_ctrl;        // 0x00
    reg [31:0] reg_status;      // 0x04
    reg [31:0] reg_cfg [0:3];   // 0x10 - 0x1C
    reg [31:0] reg_seed [0:3];  // 0x20 - 0x2C
    reg [31:0] reg_src_addr;    // 0x40
    reg [31:0] reg_dst_addr;    // 0x44
    reg [31:0] reg_len;         // 0x48

    // Internal Control Signals
    wire dma_start_pulse     = mmio_valid && (mmio_wstrb != 4'b0000) && (mmio_addr[7:0] == 8'h00) && mmio_wdata[0];
    wire seed_load_pulse     = mmio_valid && (mmio_wstrb != 4'b0000) && (mmio_addr[7:0] == 8'h00) && mmio_wdata[2];
    wire sw_load_start_pulse = mmio_valid && (mmio_wstrb != 4'b0000) && (mmio_addr[7:0] == 8'h00) && (mmio_wdata[1] || mmio_wdata[3]);

    wire mac_load_en = hw_load_mode_active ? hw_mac_load_en : reg_ctrl[1];
    wire crc_load_en = hw_load_mode_active ? hw_crc_load_en : reg_ctrl[3];
    wire any_load_en = mac_load_en || crc_load_en;

    // PRNG Instance
    wire [127:0] seed_128 = {reg_seed[3], reg_seed[2], reg_seed[1], reg_seed[0]};
    wire [127:0] prng_data_128;
    wire         prng_en;

    lfsr_prng_ctrl u_prng (
        .clk(clk),
        .rst_n(rst_n),
        .en(prng_en),
        .load_seed(seed_load_pulse),
        .seed_in(seed_128),
        .out(prng_data_128)
    );

    // Load Cores Instance Signals
    reg          mac_start;
    reg          crc_start;
    wire [127:0] mac_data_in;
    wire [127:0] crc_data_in;
    wire [127:0] cfg_128 = {reg_cfg[3], reg_cfg[2], reg_cfg[1], reg_cfg[0]};
    wire [127:0] mac_data_out;
    wire [127:0] crc_data_out;
    wire         mac_ready;
    wire         crc_ready;

    mac_load_core u_mac_load (
        .clk(clk),
        .rst_n(rst_n),
        .start(mac_start),
        .data_in(mac_data_in),
        .cfg_in(cfg_128),
        .data_out(mac_data_out),
        .ready(mac_ready)
    );

    crc_load_core u_crc_load (
        .clk(clk),
        .rst_n(rst_n),
        .start(crc_start),
        .data_in(crc_data_in),
        .cfg_in(cfg_128),
        .data_out(crc_data_out),
        .ready(crc_ready)
    );

    // DMA Data Buffers
    reg [127:0] in_buf;
    reg [127:0] out_buf;

    assign mac_data_in = any_load_en ? prng_data_128 : in_buf;
    assign crc_data_in = any_load_en ? prng_data_128 : in_buf;

    // Advance PRNG whenever a core block starts in load mode
    assign prng_en = any_load_en && (mac_start || crc_start);

    // DMA State Machine Definitions
    localparam DMA_IDLE       = 3'd0;
    localparam DMA_READ_WORD  = 3'd1;
    localparam DMA_CORE_START = 3'd2;
    localparam DMA_CORE_WAIT  = 3'd3;
    localparam DMA_WRITE_WORD = 3'd4;
    localparam DMA_DONE_ST    = 3'd5;

    reg [2:0]  dma_state;
    reg [1:0]  word_cnt;
    reg [31:0] curr_src_addr;
    reg [31:0] curr_dst_addr;
    reg [31:0] rem_blocks;
    reg        dma_core_started;

    // Load Mode State Tracking
    reg        load_active;
    reg [31:0] load_rem_blocks;
    reg        mac_running;
    reg        crc_running;

    // Software Load Mode Completion Detection
    wire sw_both_mode  = reg_ctrl[1] && reg_ctrl[3];
    wire sw_mac_done   = reg_ctrl[1] && mac_ready && mac_running && !mac_start;
    wire sw_crc_done   = reg_ctrl[3] && crc_ready && crc_running && !crc_start;
    wire sw_block_done = sw_both_mode ? (sw_mac_done && sw_crc_done) : (sw_mac_done || sw_crc_done);
    wire sw_load_done  = !hw_load_mode_active && load_active && sw_block_done && (load_rem_blocks == 32'd1);

    // Main Control and Datapath FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_state       <= DMA_IDLE;
            dma_valid       <= 1'b0;
            dma_wstrb       <= 4'b0000;
            dma_addr        <= 32'b0;
            dma_wdata       <= 32'b0;
            mac_start       <= 1'b0;
            crc_start       <= 1'b0;
            in_buf          <= 128'b0;
            out_buf         <= 128'b0;
            word_cnt        <= 2'b0;
            curr_src_addr   <= 32'b0;
            curr_dst_addr   <= 32'b0;
            rem_blocks      <= 32'b0;
            load_rem_blocks <= 32'b0;
            load_active     <= 1'b0;
            mac_running     <= 1'b0;
            crc_running     <= 1'b0;
            reg_status      <= 32'b0;
        end else begin
            // Update Status Register Bits
            reg_status[0]    <= (dma_state != DMA_IDLE);
            reg_status[2]    <= (dma_state == DMA_CORE_WAIT && !mac_ready) || mac_running;
            reg_status[3]    <= (dma_state == DMA_CORE_WAIT && !crc_ready) || crc_running;
            reg_status[31:4] <= 28'b0;

            if (any_load_en) begin
                dma_valid <= 1'b0;
                dma_wstrb <= 4'b0000;
                dma_state <= DMA_IDLE;

                if (hw_load_mode_active) begin
                    load_active <= 1'b0;

                    // Hardware-direct MAC Load Control
                    if (hw_mac_load_en) begin
                        if (mac_ready && (!mac_running || (mac_running && !mac_start))) begin
                            mac_start   <= 1'b1;
                            mac_running <= 1'b1;
                        end else begin
                            mac_start <= 1'b0;
                        end
                    end else begin
                        mac_start <= 1'b0;
                        if (mac_ready) mac_running <= 1'b0;
                    end

                    // Hardware-direct CRC Load Control
                    if (hw_crc_load_en) begin
                        if (crc_ready && (!crc_running || (crc_running && !crc_start))) begin
                            crc_start   <= 1'b1;
                            crc_running <= 1'b1;
                        end else begin
                            crc_start <= 1'b0;
                        end
                    end else begin
                        crc_start <= 1'b0;
                        if (crc_ready) crc_running <= 1'b0;
                    end
                end else begin
                    // Software Continuous / Finite Load Mode
                    if (!load_active || sw_load_start_pulse) begin
                        load_active     <= 1'b1;
                        load_rem_blocks <= reg_len;
                        reg_status[1]   <= 1'b0; // Clear DONE flag
                        if (sw_load_start_pulse ? mmio_wdata[1] : reg_ctrl[1]) begin
                            mac_start   <= 1'b1;
                            mac_running <= 1'b1;
                        end else begin
                            mac_start   <= 1'b0;
                            if (mac_ready) mac_running <= 1'b0;
                        end
                        if (sw_load_start_pulse ? mmio_wdata[3] : reg_ctrl[3]) begin
                            crc_start   <= 1'b1;
                            crc_running <= 1'b1;
                        end else begin
                            crc_start   <= 1'b0;
                            if (crc_ready) crc_running <= 1'b0;
                        end
                    end else if (sw_block_done) begin
                        if (load_rem_blocks > 32'd0) begin
                            if (load_rem_blocks == 32'd1) begin
                                reg_status[1]   <= 1'b1; // Set DONE flag
                                load_active     <= 1'b0;
                                load_rem_blocks <= 32'd0;
                                mac_running     <= 1'b0;
                                crc_running     <= 1'b0;
                                mac_start       <= 1'b0;
                                crc_start       <= 1'b0;
                            end else begin
                                load_rem_blocks <= load_rem_blocks - 1'b1;
                                if (reg_ctrl[1]) begin
                                    mac_start   <= 1'b1;
                                    mac_running <= 1'b1;
                                end
                                if (reg_ctrl[3]) begin
                                    crc_start   <= 1'b1;
                                    crc_running <= 1'b1;
                                end
                            end
                        end else begin
                            // Infinite continuous load (REG_LEN == 0)
                            if (reg_ctrl[1]) begin
                                mac_start   <= 1'b1;
                                mac_running <= 1'b1;
                            end
                            if (reg_ctrl[3]) begin
                                crc_start   <= 1'b1;
                                crc_running <= 1'b1;
                            end
                        end
                    end else begin
                        mac_start <= 1'b0;
                        crc_start <= 1'b0;
                    end
                end
            end else begin
                load_active <= 1'b0;
                if (mac_ready) mac_running <= 1'b0;
                if (crc_ready) crc_running <= 1'b0;
                mac_start   <= 1'b0;
                crc_start   <= 1'b0;

                // DMA Mode State Machine
                case (dma_state)
                    DMA_IDLE: begin
                        dma_core_started <= 1'b0;
                        if (dma_start_pulse) begin
                            curr_src_addr <= reg_src_addr;
                            curr_dst_addr <= reg_dst_addr;
                            rem_blocks    <= reg_len;
                            word_cnt      <= 2'b0;
                            reg_status[1] <= 1'b0; // Clear DONE flag
                            if (reg_len > 0) begin
                                dma_state <= DMA_READ_WORD;
                            end else begin
                                reg_status[1] <= 1'b1;
                            end
                        end
                    end

                    DMA_READ_WORD: begin
                        if (!dma_valid) begin
                            dma_valid <= 1'b1;
                            dma_wstrb <= 4'b0000;
                            dma_addr  <= curr_src_addr + {28'b0, word_cnt, 2'b00};
                        end else if (dma_ready) begin
                            dma_valid <= 1'b0;
                            case (word_cnt)
                                2'd0: in_buf[ 31:  0] <= dma_rdata;
                                2'd1: in_buf[ 63: 32] <= dma_rdata;
                                2'd2: in_buf[ 95: 64] <= dma_rdata;
                                2'd3: in_buf[127: 96] <= dma_rdata;
                            endcase

                            if (word_cnt == 2'd3) begin
                                word_cnt  <= 2'b0;
                                dma_core_started <= 1'b0;
                                dma_state <= DMA_CORE_START;
                            end else begin
                                word_cnt <= word_cnt + 1'b1;
                            end
                        end
                    end

                    DMA_CORE_START: begin
                        dma_core_started <= 1'b0;
                        case (reg_ctrl[5:4])
                            2'b00: begin
                                mac_start <= 1'b1;
                                crc_start <= 1'b0;
                            end
                            2'b01: begin
                                mac_start <= 1'b0;
                                crc_start <= 1'b1;
                            end
                            default: begin // 2'b10, 2'b11
                                mac_start <= 1'b1;
                                crc_start <= 1'b1;
                            end
                        endcase
                        dma_state <= DMA_CORE_WAIT;
                    end

                    DMA_CORE_WAIT: begin
                        mac_start <= 1'b0;
                        crc_start <= 1'b0;
                        if (!dma_core_started) begin
                            dma_core_started <= 1'b1;
                        end else begin
                            case (reg_ctrl[5:4])
                                2'b00: begin
                                    if (mac_ready) begin
                                        out_buf   <= mac_data_out;
                                        word_cnt  <= 2'b0;
                                        dma_state <= DMA_WRITE_WORD;
                                    end
                                end
                                2'b01: begin
                                    if (crc_ready) begin
                                        out_buf   <= crc_data_out;
                                        word_cnt  <= 2'b0;
                                        dma_state <= DMA_WRITE_WORD;
                                    end
                                end
                                default: begin // 2'b10, 2'b11
                                    if (mac_ready && crc_ready) begin
                                        out_buf   <= mac_data_out ^ crc_data_out;
                                        word_cnt  <= 2'b0;
                                        dma_state <= DMA_WRITE_WORD;
                                    end
                                end
                            endcase
                        end
                    end

                    DMA_WRITE_WORD: begin
                        if (!dma_valid) begin
                            dma_valid <= 1'b1;
                            dma_wstrb <= 4'b1111;
                            dma_addr  <= curr_dst_addr + {28'b0, word_cnt, 2'b00};
                            case (word_cnt)
                                2'd0: dma_wdata <= out_buf[ 31:  0];
                                2'd1: dma_wdata <= out_buf[ 63: 32];
                                2'd2: dma_wdata <= out_buf[ 95: 64];
                                2'd3: dma_wdata <= out_buf[127: 96];
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
                        reg_status[1] <= 1'b1; // Set DONE flag
                        dma_state     <= DMA_IDLE;
                    end

                    default: dma_state <= DMA_IDLE;
                endcase
            end
        end
    end

    // MMIO Slave Read/Write Interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mmio_ready   <= 1'b0;
            mmio_rdata   <= 32'b0;
            reg_ctrl     <= 32'b0;
            reg_cfg[0]   <= 32'b0;
            reg_cfg[1]   <= 32'b0;
            reg_cfg[2]   <= 32'b0;
            reg_cfg[3]   <= 32'b0;
            reg_seed[0]  <= 32'hA5A5A5A5;
            reg_seed[1]  <= 32'h5A5A5A5A;
            reg_seed[2]  <= 32'h01234567;
            reg_seed[3]  <= 32'h89ABCDEF;
            reg_src_addr <= 32'b0;
            reg_dst_addr <= 32'b0;
            reg_len      <= 32'b0;
        end else begin
            mmio_ready <= mmio_valid;

            // Auto-clear continuous load enable bits upon finite block completion
            if (sw_load_done) begin
                reg_ctrl[1] <= 1'b0;
                reg_ctrl[3] <= 1'b0;
            end

            if (mmio_valid) begin
                if (mmio_wstrb != 4'b0000) begin
                    case (mmio_addr[7:0])
                        8'h00: reg_ctrl     <= {mmio_wdata[31:3], 1'b0, mmio_wdata[1], 1'b0};
                        8'h10: reg_cfg[0]   <= mmio_wdata;
                        8'h14: reg_cfg[1]   <= mmio_wdata;
                        8'h18: reg_cfg[2]   <= mmio_wdata;
                        8'h1C: reg_cfg[3]   <= mmio_wdata;
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
                    case (mmio_addr[7:0])
                        8'h00: mmio_rdata <= reg_ctrl;
                        8'h04: mmio_rdata <= reg_status;
                        8'h10: mmio_rdata <= reg_cfg[0];
                        8'h14: mmio_rdata <= reg_cfg[1];
                        8'h18: mmio_rdata <= reg_cfg[2];
                        8'h1C: mmio_rdata <= reg_cfg[3];
                        8'h20: mmio_rdata <= reg_seed[0];
                        8'h24: mmio_rdata <= reg_seed[1];
                        8'h28: mmio_rdata <= reg_seed[2];
                        8'h2C: mmio_rdata <= reg_seed[3];
                        8'h30: mmio_rdata <= prng_data_128[31:0];
                        8'h34: mmio_rdata <= prng_data_128[63:32];
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
