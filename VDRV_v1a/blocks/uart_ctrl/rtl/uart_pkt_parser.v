module uart_pkt_parser (
    input wire clk,
    input wire rst_n,

    input wire [7:0] rx_data,
    input wire rx_valid,

    output reg cmd_set_step,
    output reg cmd_start_seq,
    output reg cmd_stop_seq,

    output reg [3:0] step_id,
    output reg [2:0] step_state,
    output reg [15:0] step_duration
);

    localparam ST_WAIT_H1    = 3'd0;
    localparam ST_WAIT_H2    = 3'd1;
    localparam ST_WAIT_CMD   = 3'd2;
    localparam ST_WAIT_DATA1 = 3'd3;
    localparam ST_WAIT_DATA2 = 3'd4;
    localparam ST_WAIT_DATA3 = 3'd5;

    reg [2:0] state;
    /* verilator lint_off UNUSEDSIGNAL */
    reg [7:0] data1_reg;
    /* verilator lint_on UNUSEDSIGNAL */
    reg [7:0] data2_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_WAIT_H1;
            cmd_set_step <= 1'b0;
            cmd_start_seq <= 1'b0;
            cmd_stop_seq <= 1'b0;
            step_id <= 4'd0;
            step_state <= 3'd0;
            step_duration <= 16'd0;
            data1_reg <= 8'd0;
            data2_reg <= 8'd0;
        end else begin
            cmd_set_step <= 1'b0;
            cmd_start_seq <= 1'b0;
            cmd_stop_seq <= 1'b0;

            if (rx_valid) begin
                case (state)
                    ST_WAIT_H1: begin
                        if (rx_data == 8'hAA) begin
                            state <= ST_WAIT_H2;
                        end
                    end
                    ST_WAIT_H2: begin
                        if (rx_data == 8'h55) begin
                            state <= ST_WAIT_CMD;
                        end else begin
                            state <= ST_WAIT_H1;
                        end
                    end
                    ST_WAIT_CMD: begin
                        if (rx_data == 8'h01) begin // CMD_SET_STEP
                            state <= ST_WAIT_DATA1;
                        end else if (rx_data == 8'h02) begin // CMD_START_SEQ
                            cmd_start_seq <= 1'b1;
                            state <= ST_WAIT_H1;
                        end else if (rx_data == 8'h03) begin // CMD_STOP_SEQ
                            cmd_stop_seq <= 1'b1;
                            state <= ST_WAIT_H1;
                        end else begin
                            state <= ST_WAIT_H1;
                        end
                    end
                    ST_WAIT_DATA1: begin
                        data1_reg <= rx_data; // contains step_state[6:4] and step_id[3:0]
                        state <= ST_WAIT_DATA2;
                    end
                    ST_WAIT_DATA2: begin
                        data2_reg <= rx_data; // Duration_H
                        state <= ST_WAIT_DATA3;
                    end
                    ST_WAIT_DATA3: begin // Duration_L
                        step_id <= data1_reg[3:0];
                        step_state <= data1_reg[6:4];
                        step_duration <= {data2_reg, rx_data};
                        cmd_set_step <= 1'b1;
                        state <= ST_WAIT_H1;
                    end
                    default: state <= ST_WAIT_H1;
                endcase
            end
        end
    end

endmodule
