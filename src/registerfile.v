`default_nettype none
module registerfile (
    input wire clk,
    input wire rst,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire rs1_valid,
    input wire rs2_valid,
    input wire [4:0] rd,
    input wire wr_en,
    input wire [31:0] rd_value,
    output reg [31:0] rs1_value,
    output reg [31:0] rs2_value
);
    reg [31:0] register_file[31:0];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            register_file[i] = 0;
    end

    always @(*) begin
        if (rs1_valid) begin
            if (rs1 == rd && wr_en && rd != 5'b0)
                rs1_value = rd_value;
            else
                rs1_value = register_file[rs1];
        end else
            rs1_value = 32'b0;

        if (rs2_valid) begin
            if (rs2 == rd && wr_en && rd != 5'b0)
                rs2_value = rd_value;
            else
                rs2_value = register_file[rs2];
        end else
            rs2_value = 32'b0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                register_file[i] <= 32'b0;
        end else begin
            register_file[0] <= 32'b0;
            if (wr_en && rd != 5'b0)
                register_file[rd] <= rd_value;
        end
    end
endmodule
