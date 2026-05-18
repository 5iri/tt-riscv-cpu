`default_nettype none
`include "include/instr_defines.vh"
module load_use_detector (
    input  wire [ 4:0] rs1_id,
    input  wire [ 4:0] rs2_id,
    input  wire        rs1_valid_id,
    input  wire        rs2_valid_id,
    input  wire [ 5:0] instr_id_ex,
    input  wire [ 4:0] rd_ex,
    input  wire        rd_valid_ex,
    output reg         stall_pipeline
);
    wire is_load_in_ex = (instr_id_ex == INSTR_LB)  || (instr_id_ex == INSTR_LH) ||
                         (instr_id_ex == INSTR_LW)  || (instr_id_ex == INSTR_LBU) ||
                         (instr_id_ex == INSTR_LHU);

    always @(*) begin
        stall_pipeline = 1'b0;
        if (is_load_in_ex && rd_valid_ex && (rd_ex != 5'b0))
            if ((rs1_valid_id && (rs1_id == rd_ex)) || (rs2_valid_id && (rs2_id == rd_ex)))
                stall_pipeline = 1'b1;
    end
endmodule
