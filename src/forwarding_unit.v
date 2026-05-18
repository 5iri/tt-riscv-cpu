`default_nettype none
`include "include/instr_defines.vh"
module forwarding_unit (
    input  wire [ 4:0] rs1_addr_ex,
    input  wire [ 4:0] rs2_addr_ex,
    input  wire        rs1_valid_ex,
    input  wire        rs2_valid_ex,
    input  wire [ 4:0] rd_addr_mem,
    input  wire        rd_valid_mem,
    input  wire [ 5:0] instr_id_mem,
    input  wire [ 4:0] rd_addr_wb,
    input  wire        rd_valid_wb,
    input  wire        wr_en_wb,
    output reg  [ 1:0] forward_a,
    output reg  [ 1:0] forward_b
);
    localparam NO_FORWARDING    = 2'b00;
    localparam FORWARD_FROM_MEM = 2'b01;
    localparam FORWARD_FROM_WB  = 2'b10;

    wire is_mem_load = (instr_id_mem == INSTR_LB)  || (instr_id_mem == INSTR_LH) ||
                       (instr_id_mem == INSTR_LW)  || (instr_id_mem == INSTR_LBU) ||
                       (instr_id_mem == INSTR_LHU);

    always @(*) begin
        forward_a = NO_FORWARDING;
        forward_b = NO_FORWARDING;

        if (rs1_valid_ex) begin
            if (rd_valid_mem && (rd_addr_mem != 5'b0) && (rd_addr_mem == rs1_addr_ex) && !is_mem_load)
                forward_a = FORWARD_FROM_MEM;
            else if (rd_valid_wb && wr_en_wb && (rd_addr_wb != 5'b0) && (rd_addr_wb == rs1_addr_ex))
                forward_a = FORWARD_FROM_WB;
        end

        if (rs2_valid_ex) begin
            if (rd_valid_mem && (rd_addr_mem != 5'b0) && (rd_addr_mem == rs2_addr_ex) && !is_mem_load)
                forward_b = FORWARD_FROM_MEM;
            else if (rd_valid_wb && wr_en_wb && (rd_addr_wb != 5'b0) && (rd_addr_wb == rs2_addr_ex))
                forward_b = FORWARD_FROM_WB;
        end
    end
endmodule
