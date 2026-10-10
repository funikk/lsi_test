module pwr_manager #(
    parameter G = 2
)(
    input  wire          clk,
    input  wire          rst_n,

    // MMIO Slave Interface (Spec 1.1)
    input  wire          mmio_valid,
    input  wire [7:0]    mmio_addr,
    input  wire [3:0]    mmio_wstrb,
    input  wire [31:0]   mmio_wdata,
    output reg  [31:0]   mmio_rdata,
    output reg           mmio_ready,

    // Load Sequencer direct hardware request
    input  wire          hw_direct_active,
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [7:0]    hw_pd_req,
    /* verilator lint_on UNUSEDSIGNAL */

    // Physical side control signals (all registered, active-high)
    output reg  [G-1:0]  sw_trickle_en,
    input  wire [G-1:0]  sw_trickle_ack,
    output reg  [G-1:0]  sw_main_en,
    input  wire [G-1:0]  sw_main_ack,
    output reg  [G-1:0]  iso_en,
    output reg  [G-1:0]  pd_rst_n,
    output wire [G-1:0]  pd_on
);

    // FSM States
    localparam ST_OFF     = 3'd0;
    localparam ST_TRICKLE = 3'd1;
    localparam ST_MAIN    = 3'd2;
    localparam ST_RST_REL = 3'd3;
    localparam ST_ON      = 3'd4;
    localparam ST_ISO     = 3'd5;
    localparam ST_SW_OFF  = 3'd6;

    // Registers
    reg [G-1:0]  reg_pd_req;
    reg [15:0]   reg_t_trickle;
    reg [15:0]   reg_t_main;
    reg [15:0]   reg_stagger;
    reg [31:0]   reg_pd_order;
    reg          reg_unsafe_mode;

    // Per-group state and timers
    reg [2:0]    state [0:7];
    reg [15:0]   fsm_timer [0:7];

    // Scheduler state
    reg [15:0]   sched_stagger_cnt;
    reg [2:0]    sched_ptr;
    reg          sched_busy;

    // Effective request
    wire [G-1:0] eff_pd_req;
    assign eff_pd_req = hw_direct_active ? hw_pd_req[G-1:0] : reg_pd_req;

    // Status / Readback signals
    reg [7:0]  status_on;
    reg [7:0]  status_trans;
    reg [7:0]  status_eff_req;
    reg [31:0] rdata_pd_req;

    integer idx;
    always @(*) begin
        status_on      = 8'd0;
        status_trans   = 8'd0;
        status_eff_req = 8'd0;
        rdata_pd_req   = 32'd0;
        for (idx = 0; idx < G; idx = idx + 1) begin
            status_on[idx]      = (state[idx] == ST_ON);
            status_trans[idx]   = (state[idx] != ST_OFF && state[idx] != ST_ON);
            status_eff_req[idx] = eff_pd_req[idx];
            rdata_pd_req[idx]   = reg_pd_req[idx];
        end
    end

    // Group pd_on continuous assignment
    genvar gi;
    generate
        for (gi = 0; gi < G; gi = gi + 1) begin : gen_pdon
            assign pd_on[gi] = (state[gi] == ST_ON);
        end
    endgenerate

    // MMIO Slave Transaction Handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mmio_ready      <= 1'b0;
            mmio_rdata      <= 32'd0;
            reg_pd_req      <= {G{1'b0}};
            reg_t_trickle   <= 16'd16;
            reg_t_main      <= 16'd16;
            reg_stagger     <= 16'd0;
            reg_pd_order    <= 32'h7654_3210;
            reg_unsafe_mode <= 1'b0;
        end else begin
            if (mmio_ready) begin
                mmio_ready <= 1'b0;
            end else if (mmio_valid) begin
                mmio_ready <= 1'b1;
                // Write handling
                if (|mmio_wstrb) begin
                    case (mmio_addr)
                        8'h00: reg_pd_req      <= mmio_wdata[G-1:0];
                        8'h08: reg_t_trickle   <= mmio_wdata[15:0];
                        8'h0C: reg_t_main      <= mmio_wdata[15:0];
                        8'h10: reg_stagger     <= mmio_wdata[15:0];
                        8'h14: reg_pd_order    <= mmio_wdata;
                        8'h18: reg_unsafe_mode <= mmio_wdata[0];
                        default: ;
                    endcase
                end
                // Read handling
                case (mmio_addr)
                    8'h00: mmio_rdata <= rdata_pd_req;
                    8'h04: mmio_rdata <= {8'h00, status_eff_req, status_trans, status_on};
                    8'h08: mmio_rdata <= {16'd0, reg_t_trickle};
                    8'h0C: mmio_rdata <= {16'd0, reg_t_main};
                    8'h10: mmio_rdata <= {16'd0, reg_stagger};
                    8'h14: mmio_rdata <= reg_pd_order;
                    8'h18: mmio_rdata <= {31'd0, reg_unsafe_mode};
                    default: mmio_rdata <= 32'd0;
                endcase
            end
        end
    end

    // Waiting groups mask
    wire [G-1:0] waiting_mask;
    generate
        for (gi = 0; gi < G; gi = gi + 1) begin : gen_wait
            assign waiting_mask[gi] = eff_pd_req[gi] && (state[gi] == ST_OFF);
        end
    endgenerate

    // Scheduler logic
    reg [G-1:0] start_group;
    reg [G-1:0] sched_start_group;
    reg [2:0]   next_sched_ptr;
    reg         next_sched_busy;
    reg [15:0]  next_sched_stagger_cnt;

    reg       found_candidate;
    reg [2:0] candidate_ptr;
    reg [3:0] candidate_grp;
    integer   k_idx;
    reg [2:0] cur_k;
    reg [3:0] cur_grp;
    reg       grp_is_waiting;
    integer   w_idx;

    always @(*) begin
        found_candidate = 1'b0;
        candidate_ptr   = 3'd0;
        candidate_grp   = 4'd0;

        for (k_idx = 0; k_idx < 8; k_idx = k_idx + 1) begin
            cur_k   = (sched_ptr + k_idx[2:0]) & 3'd7;
            cur_grp = reg_pd_order[cur_k*4 +: 4];

            grp_is_waiting = 1'b0;
            for (w_idx = 0; w_idx < G; w_idx = w_idx + 1) begin
                if ((cur_grp == w_idx[3:0]) && waiting_mask[w_idx]) begin
                    grp_is_waiting = 1'b1;
                end
            end

            if (!found_candidate && grp_is_waiting) begin
                found_candidate = 1'b1;
                candidate_ptr   = cur_k;
                candidate_grp   = cur_grp;
            end
        end

        // Fallback: any waiting group not found in PD_ORDER
        if (!found_candidate && (|waiting_mask)) begin
            for (w_idx = 0; w_idx < G; w_idx = w_idx + 1) begin
                if (!found_candidate && waiting_mask[w_idx]) begin
                    found_candidate = 1'b1;
                    candidate_ptr   = sched_ptr;
                    candidate_grp   = w_idx[3:0];
                end
            end
        end

        // Stagger scheduling decisions
        sched_start_group      = {G{1'b0}};
        next_sched_ptr         = sched_ptr;
        next_sched_busy        = sched_busy;
        next_sched_stagger_cnt = sched_stagger_cnt;

        if (!sched_busy) begin
            if (found_candidate) begin
                for (w_idx = 0; w_idx < G; w_idx = w_idx + 1) begin
                    if (candidate_grp == w_idx[3:0]) begin
                        sched_start_group[w_idx] = 1'b1;
                    end
                end
                next_sched_ptr         = (candidate_ptr + 3'd1) & 3'd7;
                next_sched_busy        = 1'b1;
                next_sched_stagger_cnt = reg_stagger;
            end else begin
                next_sched_ptr         = 3'd0;
                next_sched_busy        = 1'b0;
                next_sched_stagger_cnt = 16'd0;
            end
        end else begin
            if (sched_stagger_cnt > 16'd1) begin
                next_sched_stagger_cnt = sched_stagger_cnt - 16'd1;
            end else begin
                if (found_candidate) begin
                    for (w_idx = 0; w_idx < G; w_idx = w_idx + 1) begin
                        if (candidate_grp == w_idx[3:0]) begin
                            sched_start_group[w_idx] = 1'b1;
                        end
                    end
                    next_sched_ptr         = (candidate_ptr + 3'd1) & 3'd7;
                    next_sched_busy        = 1'b1;
                    next_sched_stagger_cnt = reg_stagger;
                end else begin
                    next_sched_ptr         = 3'd0;
                    next_sched_busy        = 1'b0;
                    next_sched_stagger_cnt = 16'd0;
                end
            end
        end

        // Priority mode: UNSAFE_MODE or STAGGER=0 starts all waiting groups simultaneously
        if (reg_unsafe_mode || (reg_stagger == 16'd0)) begin
            start_group = waiting_mask;
        end else begin
            start_group = sched_start_group;
        end
    end

    // Sequential update of scheduler state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sched_busy        <= 1'b0;
            sched_ptr         <= 3'd0;
            sched_stagger_cnt <= 16'd0;
        end else begin
            if (reg_unsafe_mode || (reg_stagger == 16'd0)) begin
                sched_busy        <= 1'b0;
                sched_ptr         <= 3'd0;
                sched_stagger_cnt <= 16'd0;
            end else begin
                sched_busy        <= next_sched_busy;
                sched_ptr         <= next_sched_ptr;
                sched_stagger_cnt <= next_sched_stagger_cnt;
            end
        end
    end

    // Group FSMs and output registers
    always @(posedge clk or negedge rst_n) begin : blk_fsm
        integer i;
        if (!rst_n) begin
            sw_trickle_en <= {G{1'b0}};
            sw_main_en    <= {G{1'b0}};
            iso_en        <= {G{1'b1}};
            pd_rst_n      <= {G{1'b0}};
            for (i = 0; i < 8; i = i + 1) begin
                state[i]     <= ST_OFF;
                fsm_timer[i] <= 16'd0;
            end
        end else begin
            for (i = 0; i < G; i = i + 1) begin
                case (state[i])
                    ST_OFF: begin
                        fsm_timer[i] <= 16'd0;
                        if (start_group[i]) begin
                            if (reg_unsafe_mode) begin
                                state[i]         <= ST_MAIN;
                                sw_trickle_en[i] <= 1'b1;
                                sw_main_en[i]    <= 1'b1;
                            end else begin
                                state[i]         <= ST_TRICKLE;
                                sw_trickle_en[i] <= 1'b1;
                                sw_main_en[i]    <= 1'b0;
                            end
                        end
                    end

                    ST_TRICKLE: begin
                        if (sw_trickle_ack[i] && (fsm_timer[i] + 16'd1 >= reg_t_trickle || reg_t_trickle == 16'd0)) begin
                            state[i]         <= ST_MAIN;
                            sw_main_en[i]    <= 1'b1;
                            fsm_timer[i]     <= 16'd0;
                        end else begin
                            fsm_timer[i] <= fsm_timer[i] + 16'd1;
                        end
                    end

                    ST_MAIN: begin
                        if (reg_unsafe_mode) begin
                            state[i]     <= ST_RST_REL;
                            pd_rst_n[i]  <= 1'b1;
                            fsm_timer[i] <= 16'd0;
                        end else if (sw_main_ack[i] && (fsm_timer[i] + 16'd1 >= reg_t_main || reg_t_main == 16'd0)) begin
                            state[i]     <= ST_RST_REL;
                            pd_rst_n[i]  <= 1'b1;
                            fsm_timer[i] <= 16'd0;
                        end else begin
                            fsm_timer[i] <= fsm_timer[i] + 16'd1;
                        end
                    end

                    ST_RST_REL: begin
                        if (fsm_timer[i] == 16'd3) begin
                            state[i]     <= ST_ON;
                            iso_en[i]    <= 1'b0;
                            fsm_timer[i] <= 16'd0;
                        end else begin
                            fsm_timer[i] <= fsm_timer[i] + 16'd1;
                        end
                    end

                    ST_ON: begin
                        fsm_timer[i] <= 16'd0;
                        if (!eff_pd_req[i]) begin
                            state[i]     <= ST_ISO;
                            iso_en[i]    <= 1'b1;
                            fsm_timer[i] <= 16'd0;
                        end
                    end

                    ST_ISO: begin
                        if (fsm_timer[i] == 16'd1) begin
                            state[i]     <= ST_SW_OFF;
                            pd_rst_n[i]  <= 1'b0;
                            fsm_timer[i] <= 16'd0;
                        end else begin
                            fsm_timer[i] <= fsm_timer[i] + 16'd1;
                        end
                    end

                    ST_SW_OFF: begin
                        if (fsm_timer[i] == 16'd1) begin
                            state[i]         <= ST_OFF;
                            sw_trickle_en[i] <= 1'b0;
                            sw_main_en[i]    <= 1'b0;
                            fsm_timer[i]     <= 16'd0;
                        end else begin
                            fsm_timer[i] <= fsm_timer[i] + 16'd1;
                        end
                    end

                    default: begin
                        state[i]     <= ST_OFF;
                        fsm_timer[i] <= 16'd0;
                    end
                endcase
            end
        end
    end

endmodule
