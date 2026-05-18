// Tiny Tapeout top: 8x8 ternary systolic-array demo rendered directly to VGA.
//
// The logical matrix is 8x8, but it is computed in two passes using a 4x8
// systolic slice so the hardware only contains 32 live PEs.
// ui_in[1:0] select one of four tiny matrix demos.
// VGA shows the 8x8 output matrix as a fullscreen heatmap:
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
    localparam integer N = 8;
    localparam integer SLICE_ROWS = 4;
    localparam integer DW = 2;
    localparam integer CW = 6;
    localparam integer LAST_FEED_PHASE = (2 * N) - 1;
    localparam integer CAPTURE_PHASE = 2 * N;

    wire rst = ~rst_n;
    wire [1:0] mode = ui_in[1:0];
    wire vblank_unused;
    wire swap_unused;

    reg clk_div2;
    always @(posedge clk or posedge rst) begin
        if (rst)
            clk_div2 <= 1'b0;
        else
            clk_div2 <= ~clk_div2;
    end

    wire core_clk = clk_div2;

    wire hsync, vsync, vga_active;
    wire [9:0] vga_px;
    wire [8:0] vga_py;
    wire [6:0] canvas_x;
    wire [5:0] canvas_y;

    vga_sync vga (
        .clk(core_clk), .rst(rst),
        .hsync(hsync), .vsync(vsync),
        .active(vga_active),
        .px(vga_px), .py(vga_py),
        .canvas_x(canvas_x), .canvas_y(canvas_y),
        .vblank(vblank_unused), .swap(swap_unused)
    );

    reg [1:0] mode_latched;
    reg [4:0] phase;
    reg       restart_pending;
    reg       pass_sel;

    reg signed [N*CW-1:0] row_store0;
    reg signed [N*CW-1:0] row_store1;
    reg signed [N*CW-1:0] row_store2;
    reg signed [N*CW-1:0] row_store3;
    reg signed [N*CW-1:0] row_store4;
    reg signed [N*CW-1:0] row_store5;
    reg signed [N*CW-1:0] row_store6;
    reg signed [N*CW-1:0] row_store7;

    wire clear = (phase == 5'd0);
    wire feeding = (phase >= 5'd1) && (phase <= LAST_FEED_PHASE[4:0]);
    wire [3:0] feed_t = phase[3:0] - 4'd1;
    wire [31:0] feed_t_ext = {28'b0, feed_t};
    wire signed [SLICE_ROWS*DW-1:0] a_in_flat;
    wire signed [N*DW-1:0] b_in_flat;
    wire signed [SLICE_ROWS*N*CW-1:0] c_out_flat;

    always @(posedge core_clk or posedge rst) begin
        if (rst) begin
            mode_latched    <= 2'b00;
            phase           <= 5'd0;
            restart_pending <= 1'b0;
            pass_sel        <= 1'b0;
            row_store0 <= '0;
            row_store1 <= '0;
            row_store2 <= '0;
            row_store3 <= '0;
            row_store4 <= '0;
            row_store5 <= '0;
            row_store6 <= '0;
            row_store7 <= '0;
        end else begin
            if (mode != mode_latched) begin
                mode_latched    <= mode;
                phase           <= 5'd0;
                restart_pending <= 1'b1;
                pass_sel        <= 1'b0;
                row_store0 <= '0;
                row_store1 <= '0;
                row_store2 <= '0;
                row_store3 <= '0;
                row_store4 <= '0;
                row_store5 <= '0;
                row_store6 <= '0;
                row_store7 <= '0;
            end else begin
                if (phase == CAPTURE_PHASE[4:0]) begin
                    if (!pass_sel) begin
                        row_store0 <= c_out_flat[(0*N*CW) +: (N*CW)];
                        row_store1 <= c_out_flat[(1*N*CW) +: (N*CW)];
                        row_store2 <= c_out_flat[(2*N*CW) +: (N*CW)];
                        row_store3 <= c_out_flat[(3*N*CW) +: (N*CW)];
                    end else begin
                        row_store4 <= c_out_flat[(0*N*CW) +: (N*CW)];
                        row_store5 <= c_out_flat[(1*N*CW) +: (N*CW)];
                        row_store6 <= c_out_flat[(2*N*CW) +: (N*CW)];
                        row_store7 <= c_out_flat[(3*N*CW) +: (N*CW)];
                    end
                end

                if (restart_pending) begin
                    phase           <= 5'd1;
                    restart_pending <= 1'b0;
                end else if (phase < CAPTURE_PHASE[4:0]) begin
                    phase <= phase + 5'd1;
                end else if (!pass_sel) begin
                    pass_sel        <= 1'b1;
                    phase           <= 5'd0;
                    restart_pending <= 1'b1;
                end
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
        input integer row;
        input integer col;
        begin
            a_coeff = 0;
            case (sel)
                2'b00: if (row == col)
                    a_coeff = ternary(1);
                2'b01: if ((row + col) == (N - 1))
                    a_coeff = ternary(1);
                2'b10: if (((row + col) & 1) == 0)
                    a_coeff = ternary(1);
                2'b11: if (row <= col)
                    a_coeff = ternary(1);
                default: a_coeff = 0;
            endcase
        end
    endfunction

    function signed [DW-1:0] b_coeff;
        input [1:0] sel;
        input integer row;
        input integer col;
        begin
            b_coeff = 0;
            case (sel)
                2'b00, 2'b01: begin
                    if (row == col)
                        b_coeff = ternary(1);
                    else if ((row + col) == (N - 1))
                        b_coeff = ternary(-1);
                    else
                        b_coeff = 0;
                end
                2'b10: if (row == col)
                    b_coeff = ternary(1);
                2'b11: if (((row + col) & 1) == 0)
                    b_coeff = ternary(-1);
                else
                    b_coeff = ternary(1);
                default: b_coeff = 0;
            endcase
        end
    endfunction

    function signed [DW-1:0] feed_a;
        input [1:0] sel;
        input integer local_row;
        input integer t;
        integer global_row;
        integer k;
        begin
            global_row = (pass_sel ? 4 : 0) + local_row;
            k = t - global_row;
            if ((k >= 0) && (k < N))
                feed_a = a_coeff(sel, global_row, k);
            else
                feed_a = 0;
        end
    endfunction

    function signed [DW-1:0] feed_b;
        input [1:0] sel;
        input integer col;
        input integer t;
        integer k;
        begin
            k = t - col;
            if ((k >= 0) && (k < N))
                feed_b = b_coeff(sel, k, col);
            else
                feed_b = 0;
        end
    endfunction

    wire signed [DW-1:0] a0 = feeding ? feed_a(mode_latched, 0, feed_t_ext) : '0;
    wire signed [DW-1:0] a1 = feeding ? feed_a(mode_latched, 1, feed_t_ext) : '0;
    wire signed [DW-1:0] a2 = feeding ? feed_a(mode_latched, 2, feed_t_ext) : '0;
    wire signed [DW-1:0] a3 = feeding ? feed_a(mode_latched, 3, feed_t_ext) : '0;
    wire signed [DW-1:0] b0 = feeding ? feed_b(mode_latched, 0, feed_t_ext) : '0;
    wire signed [DW-1:0] b1 = feeding ? feed_b(mode_latched, 1, feed_t_ext) : '0;
    wire signed [DW-1:0] b2 = feeding ? feed_b(mode_latched, 2, feed_t_ext) : '0;
    wire signed [DW-1:0] b3 = feeding ? feed_b(mode_latched, 3, feed_t_ext) : '0;
    wire signed [DW-1:0] b4 = feeding ? feed_b(mode_latched, 4, feed_t_ext) : '0;
    wire signed [DW-1:0] b5 = feeding ? feed_b(mode_latched, 5, feed_t_ext) : '0;
    wire signed [DW-1:0] b6 = feeding ? feed_b(mode_latched, 6, feed_t_ext) : '0;
    wire signed [DW-1:0] b7 = feeding ? feed_b(mode_latched, 7, feed_t_ext) : '0;

    assign a_in_flat = {a3, a2, a1, a0};
    assign b_in_flat = {b7, b6, b5, b4, b3, b2, b1, b0};

    systolic_array #(
        .ROWS(SLICE_ROWS),
        .COLS(N),
        .DW(DW),
        .CW(CW)
    ) gpu (
        .clk(core_clk),
        .rst(rst),
        .clear(clear),
        .a_in(a_in_flat),
        .b_in(b_in_flat),
        .c_out(c_out_flat)
    );

    wire [2:0] cell_row =
        (canvas_y <  6'd8) ? 3'd0 :
        (canvas_y < 6'd15) ? 3'd1 :
        (canvas_y < 6'd23) ? 3'd2 :
        (canvas_y < 6'd30) ? 3'd3 :
        (canvas_y < 6'd38) ? 3'd4 :
        (canvas_y < 6'd45) ? 3'd5 :
        (canvas_y < 6'd53) ? 3'd6 : 3'd7;

    wire [2:0] cell_col =
        (canvas_x <  7'd10) ? 3'd0 :
        (canvas_x <  7'd20) ? 3'd1 :
        (canvas_x <  7'd30) ? 3'd2 :
        (canvas_x <  7'd40) ? 3'd3 :
        (canvas_x <  7'd50) ? 3'd4 :
        (canvas_x <  7'd60) ? 3'd5 :
        (canvas_x <  7'd70) ? 3'd6 : 3'd7;

    reg signed [N*CW-1:0] selected_row;
    always @(*) begin
        case (cell_row)
            3'd0: selected_row = row_store0;
            3'd1: selected_row = row_store1;
            3'd2: selected_row = row_store2;
            3'd3: selected_row = row_store3;
            3'd4: selected_row = row_store4;
            3'd5: selected_row = row_store5;
            3'd6: selected_row = row_store6;
            default: selected_row = row_store7;
        endcase
    end

    wire signed [CW-1:0] selected_value = selected_row[(cell_col*CW) +: CW];

    function [5:0] pack_rgb;
        input [1:0] red;
        input [1:0] g;
        input [1:0] b;
        begin
            pack_rgb = {red[1], g[1], b[1], red[0], g[0], b[0]};
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
