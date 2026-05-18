`default_nettype none
`include "include/instr_defines.vh"
module alu (
    input wire [31:0] rs1,
    input wire [31:0] rs2,
    input wire [31:0] imm,
    input wire [ 5:0] instr_id,
    input wire [31:0] pc_input,
    output reg [31:0] ALUoutput
);
    always @(*) begin
        case (instr_id)
            INSTR_ADD:   ALUoutput = $signed(rs1) + $signed(rs2);
            INSTR_SUB:   ALUoutput = $signed(rs1) - $signed(rs2);
            INSTR_XOR:   ALUoutput = rs1 ^ rs2;
            INSTR_OR:    ALUoutput = rs1 | rs2;
            INSTR_AND:   ALUoutput = rs1 & rs2;
            INSTR_SLL:   ALUoutput = rs1 << rs2[4:0];
            INSTR_SRL:   ALUoutput = rs1 >> rs2[4:0];
            INSTR_SRA:   ALUoutput = $signed(rs1) >>> rs2[4:0];
            INSTR_SLT:   ALUoutput = {31'b0, $signed(rs1) < $signed(rs2)};
            INSTR_SLTU:  ALUoutput = {31'b0, rs1 < rs2};
            INSTR_ADDI:  ALUoutput = $signed(rs1) + $signed(imm);
            INSTR_XORI:  ALUoutput = rs1 ^ imm;
            INSTR_ORI:   ALUoutput = rs1 | imm;
            INSTR_ANDI:  ALUoutput = rs1 & imm;
            INSTR_SLLI:  ALUoutput = rs1 << imm[4:0];
            INSTR_SRLI:  ALUoutput = rs1 >> imm[4:0];
            INSTR_SRAI:  ALUoutput = $signed(rs1) >>> imm[4:0];
            INSTR_SLTI:  ALUoutput = {31'b0, $signed(rs1) < $signed(imm)};
            INSTR_SLTIU: ALUoutput = {31'b0, rs1 < imm};
            default:     ALUoutput = 0;
        endcase
    end
endmodule
