`default_nettype none
module pe #(
    parameter integer DW = 2,
    parameter integer CW = 6
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  clear,
    input  wire signed [DW-1:0]  a_in,
    input  wire signed [DW-1:0]  b_in,
    output reg  signed [DW-1:0]  a_out,
    output reg  signed [DW-1:0]  b_out,
    output reg  signed [CW-1:0]  c
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_out <= '0;
            b_out <= '0;
            c     <= '0;
        end else if (clear) begin
            a_out <= a_in;
            b_out <= b_in;
            c     <= '0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            c     <= c + (a_in * b_in);
        end
    end
endmodule
