// 640x480 @ 60Hz VGA sync generator, 25MHz pixel clock.
// Canvas coordinates: canvas_x = x>>3 (0..79), canvas_y = y>>3 (0..59).
// swap pulses for 1 cycle at the start of each new canvas row (every 8 real lines).
`default_nettype none
module vga_sync (
    input  wire        clk,
    input  wire        rst,
    output reg         hsync,
    output reg         vsync,
    output wire        active,
    output wire [ 9:0] px,          // pixel x (0..639 in active region)
    output wire [ 8:0] py,          // pixel y (0..479 in active region)
    output wire [ 6:0] canvas_x,    // px >> 3
    output wire [ 5:0] canvas_y,    // py >> 3
    output wire        vblank,
    output wire        swap         // 1-cycle pulse at start of each new canvas row
);
    // 640x480 @ 60Hz, 25MHz pixel clock
    localparam H_ACTIVE = 640;
    localparam H_FP     = 16;
    localparam H_SYNC   = 96;
    localparam H_BP     = 48;
    localparam H_TOTAL  = 800;  // H_ACTIVE + H_FP + H_SYNC + H_BP

    localparam V_ACTIVE = 480;
    localparam V_FP     = 10;
    localparam V_SYNC   = 2;
    localparam V_BP     = 33;
    localparam V_TOTAL  = 525;  // V_ACTIVE + V_FP + V_SYNC + V_BP

    reg [9:0] hcount; // 0..799
    reg [9:0] vcount; // 0..524

    wire h_active = (hcount < H_ACTIVE);
    wire v_active = (vcount < V_ACTIVE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hcount <= 0;
            vcount <= 0;
            hsync  <= 1;
            vsync  <= 1;
        end else begin
            if (hcount == H_TOTAL - 1) begin
                hcount <= 0;
                vcount <= (vcount == V_TOTAL - 1) ? 10'd0 : vcount + 1;
            end else
                hcount <= hcount + 1;

            hsync <= ~(hcount >= H_ACTIVE + H_FP && hcount < H_ACTIVE + H_FP + H_SYNC);
            vsync <= ~(vcount >= V_ACTIVE + V_FP && vcount < V_ACTIVE + V_FP + V_SYNC);
        end
    end

    assign active   = h_active && v_active;
    assign px       = hcount;
    assign py       = vcount[8:0];
    assign canvas_x = hcount[9:3];
    assign canvas_y = vcount[8:3]; // vcount / 8, gives 0..59 during active region
    assign vblank   = ~v_active;

    // Pulse at the first pixel of each new 8-line canvas row (hcount==0, vcount[2:0]==0, v_active)
    assign swap = (hcount == 0) && (vcount[2:0] == 3'b000) && v_active;
endmodule
