// Tiny Tapeout top: RV32I CPU + VGA (80x60 canvas @ 640x480, 6-bit color).
//
// uo_out: TT VGA PMOD standard
//   [0]=R1 [1]=G1 [2]=B1 [3]=vsync [4]=R0 [5]=G0 [6]=B0 [7]=hsync
//
// uio: SPI instruction fetch (RP2040 acts as SPI slave / instruction memory)
//   [0]=SPI_SCK(out) [1]=SPI_CS_N(out) [2]=SPI_MOSI(out) [3]=SPI_MISO(in) [7:4]=unused
//
// CPU memory map:
//   0x00000000-0xFF  256-byte data scratchpad (stack / variables)
//   0x10000000-0x4F  line buffer write: addr[6:0]=pixel_x, data[5:0]=color
//   0x10000100       VGA status (read): {24'b0, canvas_y[5:0], cpu_buf_sel, vblank}
`default_nettype none
module tt_um_siriboi_stochastic_dp (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire rst = ~rst_n;

    // ---- SPI instruction fetch ----
    wire [31:0] cpu_pc;
    wire [31:0] fetched_instr;
    wire [31:0] fetched_instr_pc;
    wire        fetch_busy;
    wire        fetch_redirect;
    wire        spi_sck, spi_cs_n, spi_mosi;
    wire        spi_miso = uio_in[3];

    spi_instr_fetch spi_fetch (
        .clk(clk), .rst(rst),
        .redirect(fetch_redirect),
        .pc(cpu_pc),
        .instr(fetched_instr),
        .instr_pc(fetched_instr_pc),
        .busy(fetch_busy),
        .spi_sck(spi_sck), .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi), .spi_miso(spi_miso)
    );

    // ---- VGA sync ----
    wire hsync, vsync, vga_active, vblank, swap;
    wire [6:0] canvas_x;
    wire [5:0] canvas_y;

    vga_sync vga (
        .clk(clk), .rst(rst),
        .hsync(hsync), .vsync(vsync),
        .active(vga_active),
        .px(), .py(),
        .canvas_x(canvas_x), .canvas_y(canvas_y),
        .vblank(vblank), .swap(swap)
    );

    // ---- CPU data bus ----
    wire [31:0] cpu_pc_out;
    wire [31:0] cpu_wr_data;
    wire        cpu_mem_wr_en;
    wire        cpu_mem_rd_en;
    wire [31:0] cpu_rd_addr;
    wire [31:0] cpu_wr_addr;
    wire [ 3:0] cpu_byte_en;
    wire [ 2:0] cpu_load_type;

    // Use write address for stores, read address for loads
    wire [31:0] data_addr = cpu_mem_wr_en ? cpu_wr_addr : cpu_rd_addr;

    // ---- Line buffer ----
    wire [5:0] vga_color;
    wire       cpu_buf_sel;
    // 0x10000000-0x1000007F: line buffer (addr>>7 == 0x200000)
    wire       line_buf_wen = cpu_mem_wr_en && (cpu_wr_addr[31:7] == 25'h200000);

    line_buffer lbuf (
        .clk(clk), .rst(rst),
        .vga_x(canvas_x), .active(vga_active), .vga_color(vga_color),
        .cpu_x(cpu_wr_addr[6:0]),
        .cpu_color(cpu_wr_data[5:0]),
        .cpu_wen(line_buf_wen),
        .swap(swap),
        .cpu_buf_sel(cpu_buf_sel)
    );

    // ---- Data scratchpad ----
    wire [31:0] sram_rd_data;
    wire        sram_sel = (data_addr[31:8] == 24'h000000);

    data_scratchpad sram (
        .clk(clk),
        .wr_en(cpu_mem_wr_en && (cpu_wr_addr[31:8] == 24'h000000)),
        .rd_en(cpu_mem_rd_en && (cpu_rd_addr[31:8] == 24'h000000)),
        .addr(data_addr),
        .wr_data(cpu_wr_data),
        .byte_en(cpu_byte_en),
        .load_type(cpu_load_type),
        .rd_data(sram_rd_data)
    );

    // ---- VGA status register ----
    wire vga_status_sel = cpu_mem_rd_en && (cpu_rd_addr == 32'h10000100);
    wire [31:0] vga_status = {24'b0, canvas_y, cpu_buf_sel, vblank};

    // ---- Memory read mux ----
    wire [31:0] mem_rd_data = vga_status_sel ? vga_status : sram_rd_data;

    // ---- RV32I CPU core ----
    riscv_cpu cpu (
        .clk(clk), .rst(rst),
        .module_instr_in(fetched_instr),
        .module_instr_pc_in(fetched_instr_pc),
        .module_read_data_in(mem_rd_data),
        .fetch_stall(fetch_busy),
        .fetch_redirect(fetch_redirect),
        .module_pc_out(cpu_pc),
        .module_wr_data_out(cpu_wr_data),
        .module_mem_wr_en(cpu_mem_wr_en),
        .module_mem_rd_en(cpu_mem_rd_en),
        .module_read_addr(cpu_rd_addr),
        .module_write_addr(cpu_wr_addr),
        .module_write_byte_enable(cpu_byte_en),
        .module_load_type(cpu_load_type)
    );

    // ---- VGA output (TT PMOD standard) ----
    assign uo_out[0] = vga_color[5]; // R1
    assign uo_out[1] = vga_color[4]; // G1
    assign uo_out[2] = vga_color[3]; // B1
    assign uo_out[3] = vsync;
    assign uo_out[4] = vga_color[2]; // R0
    assign uo_out[5] = vga_color[1]; // G0
    assign uo_out[6] = vga_color[0]; // B0
    assign uo_out[7] = hsync;

    // ---- uio: SPI outputs ----
    // uio[0]=SCK(out), [1]=CS_N(out), [2]=MOSI(out), [3]=MISO(in), [7:4]=unused
    assign uio_out = {5'b0, spi_mosi, spi_cs_n, spi_sck};
    assign uio_oe  = 8'b00000111;

    wire _unused = &{ui_in, ena};
endmodule
