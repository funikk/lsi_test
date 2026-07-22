module cpu_aes_prng_core (
    input  wire        clk,
    input  wire        rst_n,
    output wire        trap_out,

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
    input  wire        dmem_ready_i
);

    // CPU Memory Interface Wires
    wire cpu_mem_valid;
    wire cpu_mem_instr;
    wire cpu_mem_ready;
    wire [31:0] cpu_mem_addr;
    wire [31:0] cpu_mem_wdata;
    wire [3:0]  cpu_mem_wstrb;
    wire [31:0] cpu_mem_rdata;

    // Synchronized Reset Wire
    wire sync_rst_n;

    // Reset Synchronizer (Asynchronous Assert, Synchronous Deassert)
    reset_sync u_reset_sync (
        .clk(clk),
        .ext_rst_n(rst_n),
        .sync_rst_n(sync_rst_n)
    );

    // Instantiate PicoRV32 RISC-V CPU Core
    picorv32 #(
        .PROGADDR_RESET(32'h0000_0000),
        .STACKADDR(32'h0000_0800)
    ) u_cpu (
        .clk(clk),
        .resetn(sync_rst_n),
        .trap(trap_out),
        .mem_valid(cpu_mem_valid),
        .mem_instr(cpu_mem_instr),
        .mem_ready(cpu_mem_ready),
        .mem_addr(cpu_mem_addr),
        .mem_wdata(cpu_mem_wdata),
        .mem_wstrb(cpu_mem_wstrb),
        .mem_rdata(cpu_mem_rdata),
        .pcpi_valid(),
        .pcpi_insn(),
        .pcpi_rs1(),
        .pcpi_rs2(),
        .pcpi_wr(1'b0),
        .pcpi_rd(32'b0),
        .pcpi_wait(1'b0),
        .pcpi_ready(1'b0),
        .irq(32'b0),
        .eoi()
    );

    // Instruction Memory Bus Route
    assign imem_valid_o = cpu_mem_valid && cpu_mem_instr;
    assign imem_addr_o  = cpu_mem_addr;

    // CPU Data Bus Demux
    wire cpu_data_req = cpu_mem_valid && !cpu_mem_instr;
    wire is_mmio      = cpu_mem_addr[31]; // Address range 0x8000_0000+

    wire cpu_dmem_valid = cpu_data_req && !is_mmio;
    wire cpu_mmio_valid = cpu_data_req &&  is_mmio;

    // MMIO Slave Wires
    wire [31:0] mmio_rdata;
    wire mmio_ready;

    // DMA Master Wires
    wire dma_valid;
    wire [3:0] dma_wstrb;
    wire [31:0] dma_addr;
    wire [31:0] dma_wdata;
    wire [31:0] dma_rdata;
    wire dma_ready;

    // AES DMA Subsystem Instance
    aes_dma_subsys u_subsys (
        .clk(clk),
        .rst_n(sync_rst_n),
        .mmio_valid(cpu_mmio_valid),
        .mmio_wstrb(cpu_mem_wstrb),
        .mmio_addr(cpu_mem_addr),
        .mmio_wdata(cpu_mem_wdata),
        .mmio_rdata(mmio_rdata),
        .mmio_ready(mmio_ready),
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
    assign dmem_wstrb_o = dmem_sel_dma ? dma_wstrb : cpu_mem_wstrb;
    assign dmem_addr_o  = dmem_sel_dma ? dma_addr  : cpu_mem_addr;
    assign dmem_wdata_o = dmem_sel_dma ? dma_wdata : cpu_mem_wdata;

    // Route DMEM responses
    assign dma_rdata = dmem_rdata_i;
    assign dma_ready = dmem_sel_dma ? dmem_ready_i : 1'b0;

    wire cpu_dmem_ready = (!dmem_sel_dma) ? dmem_ready_i : 1'b0;

    // CPU Response Multiplexer
    assign cpu_mem_ready = cpu_mem_instr ? imem_ready_i :
                          (is_mmio       ? mmio_ready   : cpu_dmem_ready);
    assign cpu_mem_rdata = cpu_mem_instr ? imem_rdata_i :
                          (is_mmio       ? mmio_rdata   : dmem_rdata_i);

endmodule
