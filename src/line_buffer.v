// Double line buffer: 2x8 cell colors, 6-bit color each.
// VGA reads one buffer while CPU writes to the other.
// Buffers swap on the `swap` pulse from vga_sync.
// CPU always writes to the buffer VGA is NOT reading.
// Each stored cell is expanded horizontally to 10 canvas pixels on readout.
`default_nettype none
module line_buffer (
    input  wire        clk,
    input  wire        rst,

    // VGA read port (combinational)
    input  wire [ 6:0] vga_x,      // canvas_x, 0..79
    input  wire        active,
    output wire [ 5:0] vga_color,  // {R1,G1,B1,R0,G0,B0} — 2-bit per channel

    // CPU write port (cell store; only cpu_x[2:0] and wdata[5:0] matter)
    input  wire [ 6:0] cpu_x,      // cell x within line buffer (0..7)
    input  wire [ 5:0] cpu_color,
    input  wire        cpu_wen,
    input  wire        cpu_fill_both,

    // Swap from vga_sync, and status out
    input  wire        swap,
    output wire        cpu_buf_sel  // which buffer CPU should write to (informational)
);
    reg [5:0] buf0 [0:7];
    reg [5:0] buf1 [0:7];
    reg       vga_buf; // 0 = VGA reads buf0; 1 = VGA reads buf1
    wire [2:0] vga_cell_x =
        (vga_x <  7'd10) ? 3'd0 :
        (vga_x <  7'd20) ? 3'd1 :
        (vga_x <  7'd30) ? 3'd2 :
        (vga_x <  7'd40) ? 3'd3 :
        (vga_x <  7'd50) ? 3'd4 :
        (vga_x <  7'd60) ? 3'd5 :
        (vga_x <  7'd70) ? 3'd6 : 3'd7;
    wire [2:0] cpu_cell_x = cpu_x[2:0];

    integer j;
    initial begin
        for (j = 0; j < 8; j = j + 1) begin
            buf0[j] = 6'b0;
            buf1[j] = 6'b0;
        end
    end

    // VGA reads vga_buf
    assign vga_color   = active ? (vga_buf ? buf1[vga_cell_x] : buf0[vga_cell_x]) : 6'b0;
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
            if (cpu_fill_both) begin
                buf0[cpu_cell_x] <= cpu_color;
                buf1[cpu_cell_x] <= cpu_color;
            end else if (!vga_buf) // VGA reads buf0, CPU writes buf1
                buf1[cpu_cell_x] <= cpu_color;
            else           // VGA reads buf1, CPU writes buf0
                buf0[cpu_cell_x] <= cpu_color;
        end
    end
endmodule
