`default_nettype none
module systolic_array #(
    parameter integer N  = 4,
    parameter integer DW = 2,
    parameter integer CW = 6
) (
    input  wire                        clk,
    input  wire                        rst,
    input  wire                        clear,
    input  wire signed [N*DW-1:0]      a_in,
    input  wire signed [N*DW-1:0]      b_in,
    output wire signed [N*N*CW-1:0]    c_out
);
    wire signed [DW-1:0] a_bus [0:N-1][0:N];
    wire signed [DW-1:0] b_bus [0:N][0:N-1];
    wire signed [CW-1:0] c_mat [0:N-1][0:N-1];

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : gen_inputs
            assign a_bus[i][0] = a_in[(i*DW) +: DW];
            assign b_bus[0][i] = b_in[(i*DW) +: DW];
        end

        for (i = 0; i < N; i = i + 1) begin : gen_rows
            for (j = 0; j < N; j = j + 1) begin : gen_cols
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

                assign c_out[((i*N + j)*CW) +: CW] = c_mat[i][j];
            end
        end
    endgenerate
endmodule
