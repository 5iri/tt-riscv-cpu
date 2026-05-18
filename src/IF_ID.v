module IF_ID (
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,
    input  wire [31:0] pc_in,
    input  wire [31:0] instruction_in,
    input  wire        stall,
    output reg  [31:0] pc_out,
    output reg  [31:0] instruction_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out          <= 32'b0;
            instruction_out <= 32'b0;
        end else if (flush) begin
            pc_out          <= 32'b0;
            instruction_out <= 32'h00000013;
        end else if (stall) begin
            pc_out          <= pc_out;
            instruction_out <= instruction_out;
        end else begin
            pc_out          <= pc_in;
            instruction_out <= instruction_in;
        end
    end
endmodule
