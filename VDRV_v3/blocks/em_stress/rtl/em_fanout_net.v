module em_fanout_net #(
    parameter FANOUT = 64
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    output wire        fo_reduction
);

    (* keep *) reg              src;
    (* keep *) reg [FANOUT-1:0] sink;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src <= 1'b0;
        end else if (en) begin
            src <= ~src;
        end
    end

    genvar gj;
    generate
        for (gj = 0; gj < FANOUT; gj = gj + 1) begin : gen_sink
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    sink[gj] <= 1'b0;
                end else if (en) begin
                    sink[gj] <= src ^ sink[(gj + 1) % FANOUT];
                end
            end
        end
    endgenerate

    assign fo_reduction = ^sink;

endmodule
