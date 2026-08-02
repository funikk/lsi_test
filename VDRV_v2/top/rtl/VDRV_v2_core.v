module VDRV_v2_core (
    input  wire clk,
    input  wire rst_n,

    // Instruction Memory Interface (IMEM)
    output wire        imem_valid_o,
    output wire [31:0] imem_addr_o,
    input  wire [31:0] imem_rdata_i,
    input  wire        imem_ready_i,

    // Shared Data SRAM Interface (DMEM)
    output wire        dmem_valid_o,
    output wire [3:0]  dmem_wstrb_o,
    output wire [31:0] dmem_addr_o,
    output wire [31:0] dmem_wdata_o,
    input  wire [31:0] dmem_rdata_i,
    input  wire        dmem_ready_i,

    output wire trap_out,

    // UART
    input  wire uart_rx,
    output wire uart_tx,

    // Core specific I/O
    output wire aes_load_mode_en,
    output wire [1:0] cpu_load_state
);

    // CPU wires
    wire mem_valid;
    wire mem_instr;
    wire mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;
    wire [31:0] irq;
    wire [31:0] eoi;

    assign irq[31:4] = 0;
    assign irq[2:0] = 0;
    // irq[3] is load_sequencer irq

    picorv32 #(
        .ENABLE_IRQ(1),
        .ENABLE_IRQ_QREGS(1),
        .ENABLE_IRQ_TIMER(1),
        .PROGADDR_RESET(32'h0000_0000),
        .STACKADDR(32'h0000_0800)
    ) cpu (
        .clk         (clk),
        .resetn      (rst_n),
        .trap        (trap_out),
        .mem_valid   (mem_valid),
        .mem_instr   (mem_instr),
        .mem_ready   (mem_ready),
        .mem_addr    (mem_addr),
        .mem_wdata   (mem_wdata),
        .mem_wstrb   (mem_wstrb),
        .mem_rdata   (mem_rdata),
        .irq         (irq),
        .eoi         (eoi)
    );

    // Instruction Memory Bus Route
    assign imem_valid_o = mem_valid && mem_instr;
    assign imem_addr_o  = mem_addr;

    // CPU Data Bus Demux
    wire cpu_data_req = mem_valid && !mem_instr;
    wire is_mmio      = mem_addr[31]; // 0x8000_0000+

    wire cpu_dmem_valid = cpu_data_req && !is_mmio;
    wire cpu_mmio_valid = cpu_data_req &&  is_mmio;

    wire ls_mem_valid  = cpu_mmio_valid && (mem_addr[31:8] == 24'h8000_01);
    wire aes_mem_valid = cpu_mmio_valid && (mem_addr[31:8] == 24'h8000_00);
    wire pwr_mem_valid = cpu_mmio_valid && (mem_addr[31:8] == 24'h8000_02);

    // UART CTRL
    wire cmd_set_step;
    wire cmd_start_seq;
    wire cmd_stop_seq;
    wire [3:0] step_id;
    wire [1:0] step_state;
    wire [15:0] step_duration;

    uart_ctrl u_uart (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .tx(uart_tx),
        .cmd_set_step(cmd_set_step),
        .cmd_start_seq(cmd_start_seq),
        .cmd_stop_seq(cmd_stop_seq),
        .step_id(step_id),
        .step_state(step_state),
        .step_duration(step_duration)
    );

    // Load Sequencer
    wire ls_mem_ready;
    wire [31:0] ls_mem_rdata;
    wire ls_irq;
    wire aes_hw_direct_active;

    assign irq[3] = ls_irq;

    load_sequencer u_load_seq (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_set_step(cmd_set_step),
        .cmd_start_seq(cmd_start_seq),
        .cmd_stop_seq(cmd_stop_seq),
        .step_id(step_id),
        .step_state(step_state),
        .step_duration(step_duration),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_valid(ls_mem_valid),
        .mem_addr(mem_addr),
        .mem_rdata(ls_mem_rdata),
        .mem_ready(ls_mem_ready),
        .aes_load_mode_en(aes_load_mode_en),
        .hw_direct_active(aes_hw_direct_active),
        .cpu_load_state(cpu_load_state),
        .cpu_irq(ls_irq)
    );

    // AES DMA Subsystem Wires
    wire [31:0] aes_mem_rdata;
    wire aes_mem_ready;
    wire dma_valid;
    wire [3:0] dma_wstrb;
    wire [31:0] dma_addr;
    wire [31:0] dma_wdata;
    wire [31:0] dma_rdata;
    wire dma_ready;
    wire [31:0] pwr_mem_rdata;
    wire pwr_mem_ready;
    wire pd_aes_on;
    wire pd_aes_reset_n;
    wire aes_isolate;
    wire aes_quiesce_req;
    wire aes_power_ready;
    wire aes_idle;

    aes_power_manager u_aes_power_manager (
        .clk(clk),
        .rst_n(rst_n),
        .hw_direct_active(aes_hw_direct_active),
        .hw_power_req(aes_load_mode_en),
        .aes_idle(aes_idle),
        .mem_valid(pwr_mem_valid),
        .mem_wstrb(mem_wstrb),
        .mem_wdata(mem_wdata),
        .mem_rdata(pwr_mem_rdata),
        .mem_ready(pwr_mem_ready),
        .pd_aes_on(pd_aes_on),
        .pd_aes_reset_n(pd_aes_reset_n),
        .aes_isolate(aes_isolate),
        .aes_quiesce_req(aes_quiesce_req),
        .aes_power_ready(aes_power_ready)
    );

    aes_dma_subsys u_aes_dma (
        .clk(clk),
        .rst_n(rst_n),
        .hw_load_mode_active(aes_hw_direct_active),
        .hw_load_mode_en(aes_load_mode_en),
        .aes_power_ready(aes_power_ready),
        .aes_quiesce_req(aes_quiesce_req),
        .pd_aes_on(pd_aes_on),
        .pd_aes_reset_n(pd_aes_reset_n),
        .aes_isolate(aes_isolate),
        .aes_idle(aes_idle),
        .mmio_valid(aes_mem_valid),
        .mmio_wstrb(mem_wstrb),
        .mmio_addr(mem_addr),
        .mmio_wdata(mem_wdata),
        .mmio_rdata(aes_mem_rdata),
        .mmio_ready(aes_mem_ready),
        .dma_valid(dma_valid),
        .dma_wstrb(dma_wstrb),
        .dma_addr(dma_addr),
        .dma_wdata(dma_wdata),
        .dma_rdata(dma_rdata),
        .dma_ready(dma_ready)
    );

    // Main DMEM Arbiter (DMA Priority over CPU Data Access)
    wire dmem_sel_dma = dma_valid;

    assign dmem_valid_o = dmem_sel_dma ? dma_valid : cpu_dmem_valid;
    assign dmem_wstrb_o = dmem_sel_dma ? dma_wstrb : mem_wstrb;
    assign dmem_addr_o  = dmem_sel_dma ? dma_addr  : mem_addr;
    assign dmem_wdata_o = dmem_sel_dma ? dma_wdata : mem_wdata;

    // Route DMEM responses
    assign dma_rdata = dmem_rdata_i;
    assign dma_ready = dmem_sel_dma ? dmem_ready_i : 1'b0;

    wire cpu_dmem_ready = (!dmem_sel_dma) ? dmem_ready_i : 1'b0;

    // CPU Response Multiplexer
    assign mem_ready = mem_instr ? imem_ready_i :
                       (ls_mem_valid ? ls_mem_ready :
                       (aes_mem_valid ? aes_mem_ready :
                       (pwr_mem_valid ? pwr_mem_ready :
                       (is_mmio ? 1'b1 : cpu_dmem_ready)))); // Dummy ready for unmapped MMIO

    assign mem_rdata = mem_instr ? imem_rdata_i :
                       (ls_mem_valid ? ls_mem_rdata :
                       (aes_mem_valid ? aes_mem_rdata :
                       (pwr_mem_valid ? pwr_mem_rdata :
                       (is_mmio ? 32'h0 : dmem_rdata_i))));

endmodule
