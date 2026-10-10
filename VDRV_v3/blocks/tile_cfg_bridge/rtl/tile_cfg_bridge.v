module tile_cfg_bridge #(
    parameter NT = 6
)(
    input  wire                 clk,
    input  wire                 rst_n,

    // MMIO Slave Interface
    input  wire                 mmio_valid,
    input  wire [7:0]           mmio_addr,
    input  wire [3:0]           mmio_wstrb,
    input  wire [31:0]          mmio_wdata,
    output reg  [31:0]          mmio_rdata,
    output reg                  mmio_ready,

    // Config Bus Outputs (Registered)
    output reg                  cfg_valid,
    output reg  [7:0]           cfg_tile_id,
    output reg  [4:0]           cfg_addr,
    output reg  [31:0]          cfg_wdata,
    output reg                  sw_pg_sync,
    output reg  [1:0]           sw_profile_id,

    // Signature Inputs
    input  wire [NT*32-1:0]     tile_sig
);

    reg [7:0]  reg_target_tile_id;
    reg [4:0]  reg_target_cfg_addr;
    reg [1:0]  reg_sw_profile_id;
    reg [31:0] reg_sig_sel;

    reg [31:0] sig_data_selected;
    reg [31:0] sig_xor_all;
    integer i;

    always @(*) begin
        sig_data_selected = 32'd0;
        sig_xor_all       = 32'd0;
        for (i = 0; i < NT; i = i + 1) begin
            if (reg_sig_sel == i[31:0]) begin
                sig_data_selected = tile_sig[i*32 +: 32];
            end
            sig_xor_all = sig_xor_all ^ tile_sig[i*32 +: 32];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mmio_ready          <= 1'b0;
            mmio_rdata          <= 32'd0;
            cfg_valid           <= 1'b0;
            cfg_tile_id         <= 8'd0;
            cfg_addr            <= 5'd0;
            cfg_wdata           <= 32'd0;
            sw_pg_sync          <= 1'b0;
            sw_profile_id       <= 2'b00;
            reg_target_tile_id  <= 8'd0;
            reg_target_cfg_addr <= 5'd0;
            reg_sw_profile_id   <= 2'b00;
            reg_sig_sel         <= 32'd0;
        end else begin
            mmio_ready <= 1'b0;
            cfg_valid  <= 1'b0;
            sw_pg_sync <= 1'b0;

            if (mmio_valid && !mmio_ready) begin
                mmio_ready <= 1'b1;
                if (|mmio_wstrb) begin
                    case (mmio_addr)
                        8'h00: begin
                            reg_target_tile_id  <= mmio_wdata[7:0];
                            reg_target_cfg_addr <= mmio_wdata[12:8];
                        end
                        8'h04: begin
                            cfg_valid   <= 1'b1;
                            cfg_tile_id <= reg_target_tile_id;
                            cfg_addr    <= reg_target_cfg_addr;
                            cfg_wdata   <= mmio_wdata;
                        end
                        8'h08: begin
                            if (mmio_wdata[0]) begin
                                sw_pg_sync <= 1'b1;
                            end
                            reg_sw_profile_id <= mmio_wdata[5:4];
                            sw_profile_id     <= mmio_wdata[5:4];
                        end
                        8'h0C: begin
                            reg_sig_sel <= mmio_wdata;
                        end
                        default: begin
                            // Unmapped write ignored
                        end
                    endcase
                end else begin
                    case (mmio_addr)
                        8'h00: mmio_rdata <= {19'd0, reg_target_cfg_addr, reg_target_tile_id};
                        8'h04: mmio_rdata <= 32'd0;
                        8'h08: mmio_rdata <= {26'd0, reg_sw_profile_id, 4'd0};
                        8'h0C: mmio_rdata <= reg_sig_sel;
                        8'h10: mmio_rdata <= sig_data_selected;
                        8'h14: mmio_rdata <= sig_xor_all;
                        8'h18: mmio_rdata <= NT[31:0];
                        default: mmio_rdata <= 32'd0;
                    endcase
                end
            end
        end
    end

endmodule
