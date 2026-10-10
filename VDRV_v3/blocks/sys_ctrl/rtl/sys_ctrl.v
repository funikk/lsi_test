module sys_ctrl (
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

    // External / System Signals
    input  wire [3:0]  scenario_sel,
    output wire        scenario_done,
    output wire        sig_ok,
    output wire [1:0]  sw_marker,
    output wire [7:0]  sig_out
);

    // 2-stage synchronizer for asynchronous scenario_sel
    reg [3:0] scenario_sync_0;
    reg [3:0] scenario_sync_1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scenario_sync_0 <= 4'd0;
            scenario_sync_1 <= 4'd0;
        end else begin
            scenario_sync_0 <= scenario_sel;
            scenario_sync_1 <= scenario_sync_0;
        end
    end

    // Free-running 32-bit cycle counter
    reg [31:0] cycle_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 32'd0;
        end else begin
            cycle_cnt <= cycle_cnt + 32'd1;
        end
    end

    // Internal registers
    reg [1:0] reg_status;   // [0] scenario_done, [1] sig_ok
    reg [1:0] reg_marker;   // [1:0] sw_marker
    reg [7:0] reg_sig_out;  // [7:0] sig_out

    assign scenario_done = reg_status[0];
    assign sig_ok        = reg_status[1];
    assign sw_marker     = reg_marker;
    assign sig_out       = reg_sig_out;

    // MMIO read/write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mmio_ready  <= 1'b0;
            mmio_rdata  <= 32'd0;
            reg_status  <= 2'b00;
            reg_marker  <= 2'b00;
            reg_sig_out <= 8'h00;
        end else begin
            mmio_ready <= 1'b0;

            if (mmio_valid && !mmio_ready) begin
                mmio_ready <= 1'b1;
                if (|mmio_wstrb) begin
                    case (mmio_addr)
                        8'h04: reg_status  <= mmio_wdata[1:0];
                        8'h08: reg_marker  <= mmio_wdata[1:0];
                        8'h0C: reg_sig_out <= mmio_wdata[7:0];
                        default: begin
                            // Read-only or unmapped registers ignored on write
                        end
                    endcase
                end else begin
                    case (mmio_addr)
                        8'h00: mmio_rdata <= {28'd0, scenario_sync_1};
                        8'h04: mmio_rdata <= {30'd0, reg_status};
                        8'h08: mmio_rdata <= {30'd0, reg_marker};
                        8'h0C: mmio_rdata <= {24'd0, reg_sig_out};
                        8'h10: mmio_rdata <= cycle_cnt;
                        default: mmio_rdata <= 32'd0;
                    endcase
                end
            end
        end
    end

endmodule
