module em_stress #(
    parameter W = 32,
    parameter FANOUT = 64
)(
    input  wire        clk,
    input  wire        rst_n,

    // MMIO Slave Interface (Section 1.1)
    input  wire        mmio_valid,
    input  wire [7:0]  mmio_addr,
    input  wire [3:0]  mmio_wstrb,
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [31:0] mmio_wdata,
    /* verilator lint_on UNUSEDSIGNAL */
    output reg  [31:0] mmio_rdata,
    output reg         mmio_ready,

    // Hardware Sequencer Direct Control
    input  wire        hw_direct_active,
    input  wire [2:0]  hw_em_ctrl
);

    reg [2:0]  reg_em_ctrl;
    reg [31:0] em_sig;

    wire [2:0] effective_em_ctrl = hw_direct_active ? hw_em_ctrl : reg_em_ctrl;
    wire bus_en      = effective_em_ctrl[0];
    wire fo_en       = effective_em_ctrl[1];
    wire bus_pattern = effective_em_ctrl[2];
    wire misr_en     = bus_en | fo_en;

    wire [W-1:0] tx_data_w;
    wire [W-1:0] rx_data_w;
    wire         fo_reduction_w;

    em_tx_bank #(.W(W)) u_tx (
        .clk     (clk),
        .rst_n   (rst_n),
        .en      (bus_en),
        .pattern (bus_pattern),
        .tx_data (tx_data_w)
    );

    em_rx_bank #(.W(W)) u_rx (
        .clk     (clk),
        .rst_n   (rst_n),
        .rx_in   (tx_data_w),
        .rx_data (rx_data_w)
    );

    em_fanout_net #(.FANOUT(FANOUT)) u_fo (
        .clk          (clk),
        .rst_n        (rst_n),
        .en           (fo_en),
        .fo_reduction (fo_reduction_w)
    );

    reg [31:0] rx_fold;
    integer f;
    always @(*) begin
        rx_fold = 32'd0;
        for (f = 0; f < W; f = f + 1) begin
            rx_fold[f % 32] = rx_fold[f % 32] ^ rx_data_w[f];
        end
    end

    wire [31:0] misr_din = rx_fold ^ {31'b0, fo_reduction_w};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            em_sig <= 32'h0;
        end else if (misr_en) begin
            em_sig <= {em_sig[30:0], em_sig[31] ^ em_sig[21] ^ em_sig[1] ^ em_sig[0] ^ (em_sig == 32'h0)} ^ misr_din;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mmio_ready  <= 1'b0;
            mmio_rdata  <= 32'd0;
            reg_em_ctrl <= 3'd0;
        end else begin
            mmio_ready <= 1'b0;
            if (mmio_valid && !mmio_ready) begin
                mmio_ready <= 1'b1;
                if (|mmio_wstrb) begin
                    if (mmio_addr == 8'h00) begin
                        reg_em_ctrl <= mmio_wdata[2:0];
                    end
                end else begin
                    case (mmio_addr)
                        8'h00: mmio_rdata <= {29'd0, reg_em_ctrl};
                        8'h04: mmio_rdata <= em_sig;
                        default: mmio_rdata <= 32'd0;
                    endcase
                end
            end
        end
    end

endmodule
