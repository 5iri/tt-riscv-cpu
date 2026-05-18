`default_nettype none
`include "instr_defines.vh"
module decoder (
    input  wire [31:0] instr,
    output wire [ 4:0] rs2,
    output wire [ 4:0] rs1,
    output wire [31:0] imm,
    output wire [ 4:0] rd,
    output wire        rs1_valid,
    output wire        rs2_valid,
    output wire        rd_valid,
    output wire [ 6:0] opcode,
    output reg  [ 5:0] instr_id
);
    wire [2:0] func3 = instr[14:12];
    wire [6:0] func7 = instr[31:25];

    assign opcode = instr[6:0];

    wire is_r = (opcode == 7'b0110011);
    wire is_i = (opcode == 7'b0000011) || (opcode == 7'b0010011) || (opcode == 7'b1100111);
    wire is_s = (opcode == 7'b0100011);
    wire is_b = (opcode == 7'b1100011);
    wire is_u = (opcode == 7'b0010111) || (opcode == 7'b0110111);
    wire is_j = (opcode == 7'b1101111);

    assign rs1 = (is_r || is_i || is_s || is_b) ? instr[19:15] : 5'b0;
    assign rs2 = (is_r || is_s || is_b)          ? instr[24:20] : 5'b0;
    assign rd  = (is_r || is_i || is_u || is_j)  ? instr[11:7]  : 5'b0;

    assign rs1_valid = is_r || is_i || is_s || is_b;
    assign rs2_valid = is_r || is_s || is_b;
    assign rd_valid  = is_r || is_i || is_u || is_j;

    assign imm =
        is_i ? {{21{instr[31]}}, instr[30:20]} :
        is_s ? {{21{instr[31]}}, instr[30:25], instr[11:7]} :
        is_b ? {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0} :
        is_u ? {instr[31:12], 12'b0} :
        is_j ? {{12{instr[31]}}, instr[19:12], instr[20], instr[30:25], instr[24:21], 1'b0} :
        32'b0;

    always @(*) begin
        case (opcode)
            7'b0110011: begin
                case ({func7, func3})
                    {7'h00, 3'h0}: instr_id = INSTR_ADD;
                    {7'h20, 3'h0}: instr_id = INSTR_SUB;
                    {7'h00, 3'h4}: instr_id = INSTR_XOR;
                    {7'h00, 3'h6}: instr_id = INSTR_OR;
                    {7'h00, 3'h7}: instr_id = INSTR_AND;
                    {7'h00, 3'h1}: instr_id = INSTR_SLL;
                    {7'h00, 3'h5}: instr_id = INSTR_SRL;
                    {7'h20, 3'h5}: instr_id = INSTR_SRA;
                    {7'h00, 3'h2}: instr_id = INSTR_SLT;
                    {7'h00, 3'h3}: instr_id = INSTR_SLTU;
                    default:       instr_id = INSTR_INVALID;
                endcase
            end
            7'b0010011: begin
                case (func3)
                    3'h0: instr_id = INSTR_ADDI;
                    3'h4: instr_id = INSTR_XORI;
                    3'h6: instr_id = INSTR_ORI;
                    3'h7: instr_id = INSTR_ANDI;
                    3'h1: instr_id = (instr[31:25] == 7'h00) ? INSTR_SLLI : INSTR_INVALID;
                    3'h5: instr_id = (instr[31:25] == 7'h00) ? INSTR_SRLI :
                                     (instr[31:25] == 7'h20) ? INSTR_SRAI : INSTR_INVALID;
                    3'h2: instr_id = INSTR_SLTI;
                    3'h3: instr_id = INSTR_SLTIU;
                    default: instr_id = INSTR_INVALID;
                endcase
            end
            7'b0000011: begin
                case (func3)
                    3'h0: instr_id = INSTR_LB;
                    3'h1: instr_id = INSTR_LH;
                    3'h2: instr_id = INSTR_LW;
                    3'h4: instr_id = INSTR_LBU;
                    3'h5: instr_id = INSTR_LHU;
                    default: instr_id = INSTR_INVALID;
                endcase
            end
            7'b0100011: begin
                case (func3)
                    3'h0: instr_id = INSTR_SB;
                    3'h1: instr_id = INSTR_SH;
                    3'h2: instr_id = INSTR_SW;
                    default: instr_id = INSTR_INVALID;
                endcase
            end
            7'b1100011: begin
                case (func3)
                    3'h0: instr_id = INSTR_BEQ;
                    3'h1: instr_id = INSTR_BNE;
                    3'h4: instr_id = INSTR_BLT;
                    3'h5: instr_id = INSTR_BGE;
                    3'h6: instr_id = INSTR_BLTU;
                    3'h7: instr_id = INSTR_BGEU;
                    default: instr_id = INSTR_INVALID;
                endcase
            end
            7'b1101111: instr_id = INSTR_JAL;
            7'b1100111: instr_id = INSTR_JALR;
            7'b0110111: instr_id = INSTR_LUI;
            7'b0010111: instr_id = INSTR_AUIPC;
            default:    instr_id = INSTR_INVALID;
        endcase
    end
endmodule
