`default_nettype none
module systolic_array #(
    parameter integer ROWS = 4,
    parameter integer COLS = 8,
    parameter integer DW   = 2,
    parameter integer CW   = 6
) (
    input  wire                             clk,
    input  wire                             rst,
    input  wire                             clear,
    input  wire signed [ROWS*DW-1:0]        a_in,
    input  wire signed [COLS*DW-1:0]        b_in,
    output wire signed [ROWS*COLS*CW-1:0]   c_out
);
    wire signed [DW-1:0] a_bus [0:ROWS-1][0:COLS];
    wire signed [DW-1:0] b_bus [0:ROWS][0:COLS-1];
    wire signed [CW-1:0] c_mat [0:ROWS-1][0:COLS-1];

    genvar i, j;
    generate
        for (i = 0; i < ROWS; i = i + 1) begin : gen_a_inputs
            assign a_bus[i][0] = a_in[(i*DW) +: DW];
        end

        for (j = 0; j < COLS; j = j + 1) begin : gen_b_inputs
            assign b_bus[0][j] = b_in[(j*DW) +: DW];
        end

        for (i = 0; i < ROWS; i = i + 1) begin : gen_rows
            for (j = 0; j < COLS; j = j + 1) begin : gen_cols
                pe #(
                    .DW(DW),
                    .CW(CW)
                ) pe_inst (
                    .clk(clk),
                    .rst(rst),
                    .clear(clear),
                    .a_in(a_bus[i][j]),
                    .b_in(b_bus[i][j]),
                    .a_out(a_bus[i][j+1]),
                    .b_out(b_bus[i+1][j]),
                    .c(c_mat[i][j])
                );

                assign c_out[((i*COLS + j)*CW) +: CW] = c_mat[i][j];
            end
        end
    endgenerate
endmodule
