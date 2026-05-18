`default_nettype none
`include "include/instr_defines.vh"
module execution_unit (
    input  wire [31:0] rs1,
    input  wire [31:0] rs2,
    input  wire [31:0] imm,
    input  wire [ 4:0] rs1_addr,
    input  wire [ 4:0] rs2_addr,
    input  wire [ 6:0] opcode,
    input  wire [ 5:0] instr_id,
    input  wire        rs1_valid,
    input  wire        rs2_valid,
    input  wire [31:0] pc_input,
    input  wire [ 1:0] forward_a,
    input  wire [ 1:0] forward_b,
    input  wire [31:0] ex_mem_result,
    input  wire [31:0] mem_wb_result,
    output reg  [31:0] exec_output,
    output reg         jump_signal,
    output reg  [31:0] jump_addr,
    output reg  [31:0] mem_addr,
    output reg  [31:0] rs1_value_out,
    output reg  [31:0] rs2_value_out,
    output reg         flush_pipeline
);
    localparam NO_FORWARDING    = 2'b00;
    localparam FORWARD_FROM_MEM = 2'b01;
    localparam FORWARD_FROM_WB  = 2'b10;

    reg [31:0] rs1_value;
    reg [31:0] rs2_value;

    assign rs1_value_out = rs1_value;
    assign rs2_value_out = rs2_value;

    always @(*) begin
        case (forward_a)
            FORWARD_FROM_MEM: rs1_value = ex_mem_result;
            FORWARD_FROM_WB:  rs1_value = mem_wb_result;
            default:          rs1_value = rs1;
        endcase
        case (forward_b)
            FORWARD_FROM_MEM: rs2_value = ex_mem_result;
            FORWARD_FROM_WB:  rs2_value = mem_wb_result;
            default:          rs2_value = rs2;
        endcase
    end

    alu alu_inst (
        .rs1(rs1_value),
        .rs2(rs2_value),
        .imm(imm),
        .instr_id(instr_id),
        .pc_input(pc_input),
        .ALUoutput()
    );

    always @(*) begin
        exec_output    = 32'b0;
        jump_signal    = 1'b0;
        jump_addr      = 32'b0;
        mem_addr       = 32'b0;
        flush_pipeline = 1'b0;

        case (opcode)
            7'b0110011: exec_output = alu_inst.ALUoutput;
            7'b0010011: exec_output = alu_inst.ALUoutput;
            7'b0000011: mem_addr    = rs1_value + imm;
            7'b0100011: mem_addr    = rs1_value + imm;
            7'b1100011: begin
                case (instr_id)
                    INSTR_BEQ:  if (rs1_value == rs2_value)                     begin jump_signal = 1; jump_addr = pc_input + imm; flush_pipeline = 1; end
                    INSTR_BNE:  if (rs1_value != rs2_value)                     begin jump_signal = 1; jump_addr = pc_input + imm; flush_pipeline = 1; end
                    INSTR_BLT:  if ($signed(rs1_value) <  $signed(rs2_value))   begin jump_signal = 1; jump_addr = pc_input + imm; flush_pipeline = 1; end
                    INSTR_BGE:  if ($signed(rs1_value) >= $signed(rs2_value))   begin jump_signal = 1; jump_addr = pc_input + imm; flush_pipeline = 1; end
                    INSTR_BLTU: if (rs1_value <  rs2_value)                     begin jump_signal = 1; jump_addr = pc_input + imm; flush_pipeline = 1; end
                    INSTR_BGEU: if (rs1_value >= rs2_value)                     begin jump_signal = 1; jump_addr = pc_input + imm; flush_pipeline = 1; end
                    default: ;
                endcase
            end
            7'b1101111: begin  // JAL
                jump_signal    = 1;
                jump_addr      = pc_input + imm;
                exec_output    = pc_input + 32'd4;
                flush_pipeline = 1;
            end
            7'b1100111: begin  // JALR
                jump_signal    = 1;
                jump_addr      = (rs1_value + imm) & 32'hFFFFFFFE;
                exec_output    = pc_input + 32'd4;
                flush_pipeline = 1;
            end
            7'b0110111: exec_output = imm;              // LUI
            7'b0010111: exec_output = pc_input + imm;   // AUIPC
            default: ;
        endcase
    end
endmodule
