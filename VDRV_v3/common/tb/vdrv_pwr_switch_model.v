// Testbench Power Switch Behavioral Model
// Models delay of power switch daisy chains.
// en must be 1 for DELAY consecutive cycles for ack=1.
// ack drops to 0 after en is 0 for DELAY consecutive cycles.

`timescale 1ns/1ps

module vdrv_pwr_switch_model #(
    parameter DELAY = 8
)(
    input  wire clk,
    input  wire rst_n,
    input  wire en,
    output reg  ack
);

    reg [31:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack <= 1'b0;
            cnt <= 32'd0;
        end else begin
            if (DELAY == 0) begin
                ack <= en;
                cnt <= 32'd0;
            end else if (en) begin
                if (ack) begin
                    cnt <= 32'd0;
                end else begin
                    if (cnt + 1 >= DELAY) begin
                        ack <= 1'b1;
                        cnt <= 32'd0;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
            end else begin
                if (!ack) begin
                    cnt <= 32'd0;
                end else begin
                    if (cnt + 1 >= DELAY) begin
                        ack <= 1'b0;
                        cnt <= 32'd0;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
            end
        end
    end

endmodule
