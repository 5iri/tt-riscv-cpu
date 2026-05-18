// Double line buffer: 2x80 pixels, 6-bit color each.
// VGA reads one buffer while CPU writes to the other.
// Buffers swap on the `swap` pulse from vga_sync.
// CPU always writes to the buffer VGA is NOT reading.
`default_nettype none
module line_buffer (
    input  wire        clk,
    input  wire        rst,

    // VGA read port (combinational)
    input  wire [ 6:0] vga_x,      // canvas_x, 0..79
    input  wire        active,
    output wire [ 5:0] vga_color,  // {R1,G1,B1,R0,G0,B0} — 2-bit per channel

    // CPU write port (byte store; only addr[6:0] and wdata[5:0] matter)
    input  wire [ 6:0] cpu_x,      // pixel x within line buffer (0..79)
    input  wire [ 5:0] cpu_color,
    input  wire        cpu_wen,

    // Swap from vga_sync, and status out
    input  wire        swap,
    output wire        cpu_buf_sel  // which buffer CPU should write to (informational)
);
    reg [5:0] buf0 [0:79];
    reg [5:0] buf1 [0:79];
    reg       vga_buf; // 0 = VGA reads buf0; 1 = VGA reads buf1

    integer j;
    initial begin
        for (j = 0; j < 80; j = j + 1) begin
            buf0[j] = 6'b0;
            buf1[j] = 6'b0;
        end
    end

    // VGA reads vga_buf
    assign vga_color   = active ? (vga_buf ? buf1[vga_x] : buf0[vga_x]) : 6'b0;
    // CPU writes to the other buffer
    assign cpu_buf_sel = ~vga_buf;

    always @(posedge clk or posedge rst) begin
        if (rst)
            vga_buf <= 0;
        else if (swap)
            vga_buf <= ~vga_buf;
    end

    always @(posedge clk) begin
        if (cpu_wen) begin
            if (!vga_buf) // VGA reads buf0, CPU writes buf1
                buf1[cpu_x] <= cpu_color;
            else           // VGA reads buf1, CPU writes buf0
                buf0[cpu_x] <= cpu_color;
        end
    end
endmodule
