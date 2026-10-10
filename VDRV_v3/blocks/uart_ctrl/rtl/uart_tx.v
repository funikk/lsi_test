module uart_tx (
    input wire clk,
    input wire rst_n,
    input wire tx_start,
    input wire [7:0] tx_data,
    output reg tx_active,
    output reg tx
);

    parameter CLK_PER_BIT = 868;

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [15:0] clk_cnt;
    reg [2:0] bit_cnt;
    reg [7:0] tx_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            clk_cnt <= 0;
            bit_cnt <= 0;
            tx_shift <= 0;
            tx_active <= 0;
            tx <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (tx_start) begin
                        tx_shift <= tx_data;
                        tx_active <= 1'b1;
                        state <= START;
                        tx <= 1'b0; // Start bit
                    end
                end
                START: begin
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        state <= DATA;
                        tx <= tx_shift[0];
                        tx_shift <= {1'b0, tx_shift[7:1]};
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                DATA: begin
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        if (bit_cnt == 7) begin
                            bit_cnt <= 0;
                            state <= STOP;
                            tx <= 1'b1; // Stop bit
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                            tx <= tx_shift[0];
                            tx_shift <= {1'b0, tx_shift[7:1]};
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                STOP: begin
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        tx_active <= 1'b0;
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
