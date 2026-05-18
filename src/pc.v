module pc (
    input  wire        clk,
    input  wire        rst,
    input  wire        j_signal,
    input  wire        stall,
    input  wire [31:0] jump,
    output wire [31:0] out
);
    reg [31:0] next_pc = 32'd0;

    always @(posedge clk) begin
        if (rst)
            next_pc <= 32'b0;
        else if (j_signal)
            next_pc <= jump;
        else if (stall)
            next_pc <= next_pc;
        else
            next_pc <= next_pc + 32'h4;
    end

    assign out = next_pc;
endmodule
