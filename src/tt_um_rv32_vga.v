// Tiny Tapeout top: 4x4 ternary systolic-array demo rendered directly to VGA.
//
// ui_in[1:0] select one of four tiny matrix demos.
// The systolic array runs after reset or when the mode changes.
// VGA shows the 4x4 output matrix as a fullscreen heatmap:
//   positive values -> green
//   negative values -> red
//   zero            -> blue
`default_nettype none
module tt_um_rv32_vga (
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
    localparam integer N  = 4;
    localparam integer DW = 2;
    localparam integer CW = 6;

    wire [1:0] mode = ui_in[1:0];
    wire vblank_unused;
    wire swap_unused;

    // ---- VGA sync ----
    wire hsync, vsync, vga_active;
    wire [9:0] vga_px;
    wire [8:0] vga_py;
    wire [6:0] canvas_x;
    wire [5:0] canvas_y;

    vga_sync vga (
        .clk(clk), .rst(rst),
        .hsync(hsync), .vsync(vsync),
        .active(vga_active),
        .px(vga_px), .py(vga_py),
        .canvas_x(canvas_x), .canvas_y(canvas_y),
        .vblank(vblank_unused), .swap(swap_unused)
    );

    // ---- Array control ----
    reg  [1:0] mode_latched;
    reg  [3:0] phase;
    reg        restart_pending;

    wire clear = (phase == 4'd0);
    wire feeding = (phase >= 4'd1) && (phase <= 4'd7);
    wire [2:0] feed_t = phase[2:0] - 3'd1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mode_latched     <= 2'b00;
            phase            <= 4'd0;
            restart_pending  <= 1'b0;
        end else begin
            if (mode != mode_latched) begin
                mode_latched    <= mode;
                phase           <= 4'd0;
                restart_pending <= 1'b1;
            end else if (restart_pending) begin
                phase           <= 4'd1;
                restart_pending <= 1'b0;
            end else if (phase < 4'd8) begin
                phase <= phase + 4'd1;
            end
        end
    end

    function signed [DW-1:0] ternary;
        input integer value;
        begin
            case (value)
                -1: ternary = -1;
                 1: ternary =  1;
                default: ternary = 0;
            endcase
        end
    endfunction

    function signed [DW-1:0] a_coeff;
        input [1:0] sel;
        input [1:0] row;
        input [1:0] col;
        begin
            a_coeff = 0;
            case (sel)
                2'b00: begin
                    if (row == col)
                        a_coeff = ternary(1);
                end
                2'b01: begin
                    if ((row + col) == 3)
                        a_coeff = ternary(1);
                end
                2'b10: begin
                    case ({row, col})
                        4'b0000, 4'b0010, 4'b0101, 4'b0111,
                        4'b1000, 4'b1010, 4'b1101, 4'b1111: a_coeff = ternary(1);
                        4'b0001, 4'b0011, 4'b0100, 4'b0110,
                        4'b1001, 4'b1011, 4'b1100, 4'b1110: a_coeff = ternary(-1);
                        default: a_coeff = 0;
                    endcase
                end
                2'b11: begin
                    case ({row, col})
                        4'b0000, 4'b0001, 4'b0010, 4'b0011,
                        4'b0100, 4'b0110, 4'b1001, 4'b1011,
                        4'b1100, 4'b1101, 4'b1110, 4'b1111: a_coeff = ternary(1);
                        default: a_coeff = 0;
                    endcase
                end
                default: a_coeff = 0;
            endcase
        end
    endfunction

    function signed [DW-1:0] b_coeff;
        input [1:0] sel;
        input [1:0] row;
        input [1:0] col;
        begin
            b_coeff = 0;
            case (sel)
                2'b00, 2'b01: begin
                    case ({row, col})
                        4'b0000, 4'b0011, 4'b0101, 4'b0110,
                        4'b1001, 4'b1010, 4'b1100, 4'b1111: b_coeff = ternary(1);
                        4'b0010, 4'b0111, 4'b1000, 4'b1101: b_coeff = ternary(-1);
                        default: b_coeff = 0;
                    endcase
                end
                2'b10: begin
                    if (row == col)
                        b_coeff = ternary(1);
                end
                2'b11: begin
                    case ({row, col})
                        4'b0000, 4'b0010, 4'b0101, 4'b0111,
                        4'b1000, 4'b1010, 4'b1101, 4'b1111: b_coeff = ternary(-1);
                        4'b0001, 4'b0011, 4'b0100, 4'b0110,
                        4'b1001, 4'b1011, 4'b1100, 4'b1110: b_coeff = ternary(1);
                        default: b_coeff = 0;
                    endcase
                end
                default: b_coeff = 0;
            endcase
        end
    endfunction

    function signed [DW-1:0] feed_a;
        input [1:0] sel;
        input [1:0] row;
        input [2:0] t;
        integer k;
        begin
            k = {29'b0, t} - {30'b0, row};
            if ((k >= 0) && (k < N))
                feed_a = a_coeff(sel, row, k[1:0]);
            else
                feed_a = 0;
        end
    endfunction

    function signed [DW-1:0] feed_b;
        input [1:0] sel;
        input [1:0] col;
        input [2:0] t;
        integer k;
        begin
            k = {29'b0, t} - {30'b0, col};
            if ((k >= 0) && (k < N))
                feed_b = b_coeff(sel, k[1:0], col);
            else
                feed_b = 0;
        end
    endfunction

    wire signed [DW-1:0] a0 = feeding ? feed_a(mode_latched, 2'd0, feed_t) : '0;
    wire signed [DW-1:0] a1 = feeding ? feed_a(mode_latched, 2'd1, feed_t) : '0;
    wire signed [DW-1:0] a2 = feeding ? feed_a(mode_latched, 2'd2, feed_t) : '0;
    wire signed [DW-1:0] a3 = feeding ? feed_a(mode_latched, 2'd3, feed_t) : '0;
    wire signed [DW-1:0] b0 = feeding ? feed_b(mode_latched, 2'd0, feed_t) : '0;
    wire signed [DW-1:0] b1 = feeding ? feed_b(mode_latched, 2'd1, feed_t) : '0;
    wire signed [DW-1:0] b2 = feeding ? feed_b(mode_latched, 2'd2, feed_t) : '0;
    wire signed [DW-1:0] b3 = feeding ? feed_b(mode_latched, 2'd3, feed_t) : '0;

    wire signed [N*DW-1:0] a_in_flat = {a3, a2, a1, a0};
    wire signed [N*DW-1:0] b_in_flat = {b3, b2, b1, b0};
    wire signed [N*N*CW-1:0] c_out_flat;

    systolic_array #(
        .N(N),
        .DW(DW),
        .CW(CW)
    ) gpu (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .a_in(a_in_flat),
        .b_in(b_in_flat),
        .c_out(c_out_flat)
    );

    wire signed [CW-1:0] c00 = c_out_flat[( 0*CW) +: CW];
    wire signed [CW-1:0] c01 = c_out_flat[( 1*CW) +: CW];
    wire signed [CW-1:0] c02 = c_out_flat[( 2*CW) +: CW];
    wire signed [CW-1:0] c03 = c_out_flat[( 3*CW) +: CW];
    wire signed [CW-1:0] c10 = c_out_flat[( 4*CW) +: CW];
    wire signed [CW-1:0] c11 = c_out_flat[( 5*CW) +: CW];
    wire signed [CW-1:0] c12 = c_out_flat[( 6*CW) +: CW];
    wire signed [CW-1:0] c13 = c_out_flat[( 7*CW) +: CW];
    wire signed [CW-1:0] c20 = c_out_flat[( 8*CW) +: CW];
    wire signed [CW-1:0] c21 = c_out_flat[( 9*CW) +: CW];
    wire signed [CW-1:0] c22 = c_out_flat[(10*CW) +: CW];
    wire signed [CW-1:0] c23 = c_out_flat[(11*CW) +: CW];
    wire signed [CW-1:0] c30 = c_out_flat[(12*CW) +: CW];
    wire signed [CW-1:0] c31 = c_out_flat[(13*CW) +: CW];
    wire signed [CW-1:0] c32 = c_out_flat[(14*CW) +: CW];
    wire signed [CW-1:0] c33 = c_out_flat[(15*CW) +: CW];

    wire [1:0] cell_row = (canvas_y < 6'd15) ? 2'd0 :
                          (canvas_y < 6'd30) ? 2'd1 :
                          (canvas_y < 6'd45) ? 2'd2 : 2'd3;
    wire [1:0] cell_col = (canvas_x < 7'd20) ? 2'd0 :
                          (canvas_x < 7'd40) ? 2'd1 :
                          (canvas_x < 7'd60) ? 2'd2 : 2'd3;

    reg signed [CW-1:0] selected_value;
    always @(*) begin
        case ({cell_row, cell_col})
            4'h0: selected_value = c00;
            4'h1: selected_value = c01;
            4'h2: selected_value = c02;
            4'h3: selected_value = c03;
            4'h4: selected_value = c10;
            4'h5: selected_value = c11;
            4'h6: selected_value = c12;
            4'h7: selected_value = c13;
            4'h8: selected_value = c20;
            4'h9: selected_value = c21;
            4'hA: selected_value = c22;
            4'hB: selected_value = c23;
            4'hC: selected_value = c30;
            4'hD: selected_value = c31;
            4'hE: selected_value = c32;
            default: selected_value = c33;
        endcase
    end

    function [5:0] pack_rgb;
        input [1:0] r;
        input [1:0] g;
        input [1:0] b;
        begin
            pack_rgb = {r[1], g[1], b[1], r[0], g[0], b[0]};
        end
    endfunction

    function [5:0] heatmap_color;
        input signed [CW-1:0] value;
        reg [1:0] level;
        reg signed [CW-1:0] abs_value;
        begin
            abs_value = value[CW-1] ? -value : value;
            if (abs_value >= 3)
                level = 2'b11;
            else if (abs_value == 2)
                level = 2'b10;
            else if (abs_value == 1)
                level = 2'b01;
            else
                level = 2'b00;

            if (value > 0)
                heatmap_color = pack_rgb(2'b00, level, 2'b00);
            else if (value < 0)
                heatmap_color = pack_rgb(level, 2'b00, 2'b00);
            else
                heatmap_color = pack_rgb(2'b00, 2'b00, 2'b01);
        end
    endfunction

    wire [5:0] vga_color = vga_active ? heatmap_color(selected_value) : 6'b0;

    assign uo_out[0] = vga_color[5];
    assign uo_out[1] = vga_color[4];
    assign uo_out[2] = vga_color[3];
    assign uo_out[3] = vsync;
    assign uo_out[4] = vga_color[2];
    assign uo_out[5] = vga_color[1];
    assign uo_out[6] = vga_color[0];
    assign uo_out[7] = hsync;

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire _unused = &{uio_in, ena, ui_in[7:2], vga_px, vga_py, vblank_unused, swap_unused};
endmodule
