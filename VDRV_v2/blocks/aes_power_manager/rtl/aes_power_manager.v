module aes_power_manager (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        hw_direct_active,
    input  wire        hw_power_req,
    input  wire        aes_idle,

    input  wire        mem_valid,
    input  wire [3:0]  mem_wstrb,
    input  wire [31:0] mem_wdata,
    output reg  [31:0] mem_rdata,
    output reg         mem_ready,

    output reg         pd_aes_on,
    output reg         pd_aes_reset_n,
    output reg         aes_isolate,
    output reg         aes_quiesce_req,
    output reg         aes_power_ready
);

    localparam ST_OFF      = 3'd0;
    localparam ST_POWER_UP = 3'd1;
    localparam ST_ON       = 3'd2;
    localparam ST_QUIESCE  = 3'd3;
    localparam ST_ISOLATE  = 3'd4;

    reg [2:0] state;
    reg [1:0] startup_count;
    reg sw_power_req;

    wire effective_power_req = hw_direct_active ? hw_power_req : sw_power_req;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sw_power_req <= 1'b0;
            mem_ready    <= 1'b0;
        end else begin
            mem_ready <= mem_valid;
            if (mem_valid && (mem_wstrb != 4'b0)) begin
                sw_power_req <= mem_wdata[0];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_OFF;
            startup_count <= 2'd0;
        end else begin
            case (state)
                ST_OFF: begin
                    if (effective_power_req) begin
                        state         <= ST_POWER_UP;
                        startup_count <= 2'd2;
                    end
                end
                ST_POWER_UP: begin
                    if (!effective_power_req) begin
                        state <= ST_OFF;
                    end else if (startup_count != 0) begin
                        startup_count <= startup_count - 1'b1;
                    end else begin
                        state <= ST_ON;
                    end
                end
                ST_ON: begin
                    if (!effective_power_req) state <= ST_QUIESCE;
                end
                ST_QUIESCE: begin
                    if (effective_power_req) begin
                        state <= ST_ON;
                    end else if (aes_idle) begin
                        state <= ST_ISOLATE;
                    end
                end
                ST_ISOLATE: begin
                    if (effective_power_req) state <= ST_ON;
                    else state <= ST_OFF;
                end
                default: state <= ST_OFF;
            endcase
        end
    end

    always @* begin
        pd_aes_on       = 1'b0;
        pd_aes_reset_n  = 1'b0;
        aes_isolate     = 1'b1;
        aes_quiesce_req = 1'b1;
        aes_power_ready = 1'b0;
        case (state)
            ST_POWER_UP: begin
                pd_aes_on = 1'b1;
            end
            ST_ON: begin
                pd_aes_on       = 1'b1;
                pd_aes_reset_n  = 1'b1;
                aes_isolate     = 1'b0;
                aes_quiesce_req = 1'b0;
                aes_power_ready = 1'b1;
            end
            ST_QUIESCE: begin
                pd_aes_on       = 1'b1;
                pd_aes_reset_n  = 1'b1;
                aes_isolate     = 1'b0;
                aes_quiesce_req = 1'b1;
            end
            ST_ISOLATE: begin
                pd_aes_on       = 1'b1;
                aes_isolate     = 1'b1;
                aes_quiesce_req = 1'b1;
            end
            default: begin end
        endcase
    end

    always @* begin
        mem_rdata = 32'b0;
        if (mem_valid && (mem_wstrb == 4'b0)) begin
            mem_rdata[0]   = effective_power_req;
            mem_rdata[1]   = pd_aes_on;
            mem_rdata[2]   = (state == ST_POWER_UP) || (state == ST_QUIESCE) || (state == ST_ISOLATE);
            mem_rdata[3]   = aes_isolate;
            mem_rdata[4]   = aes_idle;
            mem_rdata[7:5] = state;
        end
    end
endmodule
