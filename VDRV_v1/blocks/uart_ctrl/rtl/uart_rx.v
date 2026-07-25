module uart_rx (
    input wire clk,
    input wire rst_n,
    input wire rx,
    output reg [7:0] rx_data,
    output reg rx_valid
);

    parameter CLK_PER_BIT = 868; // 100MHz / 115200bps = 868

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [15:0] clk_cnt;
    reg [2:0] bit_cnt;
    reg [7:0] rx_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            clk_cnt <= 0;
            bit_cnt <= 0;
            rx_shift <= 0;
            rx_data <= 0;
            rx_valid <= 0;
        end else begin
            rx_valid <= 1'b0; // Default

            case (state)
                IDLE: begin
                    clk_cnt <= 0;
                    if (rx == 1'b0) begin // Start bit detected
                        state <= START;
                    end
                end
                START: begin
                    if (clk_cnt == CLK_PER_BIT/2) begin
                        if (rx == 1'b0) begin
                            clk_cnt <= 0;
                            state <= DATA;
                        end else begin
                            state <= IDLE; // False start
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                DATA: begin
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        rx_shift <= {rx, rx_shift[7:1]};
                        if (bit_cnt == 7) begin
                            bit_cnt <= 0;
                            state <= STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                STOP: begin
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        if (rx == 1'b1) begin
                            rx_data <= rx_shift;
                            rx_valid <= 1'b1;
                        end
                        state <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
