`default_nettype none
module riscv_cpu (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] module_instr_in,
    input  wire [31:0] module_instr_pc_in,
    input  wire [31:0] module_read_data_in,
    input  wire        fetch_stall,           // from SPI fetch module
    output wire        fetch_redirect,
    output wire [31:0] module_pc_out,
    output wire [31:0] module_wr_data_out,
    output wire        module_mem_wr_en,
    output wire        module_mem_rd_en,
    output wire [31:0] module_read_addr,
    output wire [31:0] module_write_addr,
    output wire [ 3:0] module_write_byte_enable,
    output wire [ 2:0] module_load_type
);
    // ---- PC ----
    wire [31:0] pc_out;
    wire        jump_signal;
    wire [31:0] jump_addr;
    wire        stall_load_use;
    wire        stall_pipeline = stall_load_use || fetch_stall;

    pc pc_inst (
        .clk(clk), .rst(rst),
        .j_signal(jump_signal),
        .jump(jump_addr),
        .stall(stall_pipeline),
        .out(pc_out)
    );
    assign module_pc_out = pc_out;

    // ---- IF/ID ----
    wire        branch_flush = jump_signal;
    wire [31:0] if_id_pc;
    wire [31:0] if_id_instr;

    IF_ID if_id_inst (
        .clk(clk), .rst(rst),
        .flush(branch_flush),
        .pc_in(module_instr_pc_in),
        .instruction_in(module_instr_in),
        .stall(stall_pipeline),
        .pc_out(if_id_pc),
        .instruction_out(if_id_instr)
    );

    // ---- Decode ----
    wire [ 4:0] dec_rs1, dec_rs2, dec_rd;
    wire [31:0] dec_imm;
    wire        dec_rs1_valid, dec_rs2_valid, dec_rd_valid;
    wire [ 6:0] dec_opcode;
    wire [ 5:0] dec_instr_id;

    decoder dec_inst (
        .instr(if_id_instr),
        .rs1(dec_rs1), .rs2(dec_rs2), .rd(dec_rd),
        .imm(dec_imm),
        .rs1_valid(dec_rs1_valid), .rs2_valid(dec_rs2_valid), .rd_valid(dec_rd_valid),
        .opcode(dec_opcode),
        .instr_id(dec_instr_id)
    );

    // ---- Load-use hazard ----
    wire [31:0] id_ex_pc;
    wire [ 5:0] id_ex_instr_id;
    wire [ 4:0] id_ex_rd;
    wire        id_ex_rd_valid;

    load_use_detector lud_inst (
        .rs1_id(dec_rs1), .rs2_id(dec_rs2),
        .rs1_valid_id(dec_rs1_valid), .rs2_valid_id(dec_rs2_valid),
        .instr_id_ex(id_ex_instr_id),
        .rd_ex(id_ex_rd),
        .rd_valid_ex(id_ex_rd_valid),
        .stall_pipeline(stall_load_use)
    );

    // ---- Register File ----
    wire [31:0] rf_rs1_value, rf_rs2_value;
    wire [ 4:0] rf_rd;
    wire        rf_wr_en;
    wire [31:0] rf_rd_value;

    registerfile rf_inst (
        .clk(clk), .rst(rst),
        .rs1(dec_rs1), .rs2(dec_rs2),
        .rs1_valid(dec_rs1_valid), .rs2_valid(dec_rs2_valid),
        .rd(rf_rd), .wr_en(rf_wr_en), .rd_value(rf_rd_value),
        .rs1_value(rf_rs1_value), .rs2_value(rf_rs2_value)
    );

    // ---- ID/EX ----
    wire        id_ex_rs1_valid, id_ex_rs2_valid;
    wire [31:0] id_ex_imm;
    wire [ 4:0] id_ex_rs1_addr, id_ex_rs2_addr;
    wire [ 6:0] id_ex_opcode;
    wire [31:0] id_ex_rs1_value, id_ex_rs2_value;

    wire execution_flush;
    wire pipeline_flush = branch_flush || execution_flush;

    ID_EX id_ex_inst (
        .clk(clk), .rst(rst),
        .rs1_valid_in(dec_rs1_valid), .rs2_valid_in(dec_rs2_valid), .rd_valid_in(dec_rd_valid),
        .imm_in(dec_imm),
        .rs1_addr_in(dec_rs1), .rs2_addr_in(dec_rs2), .rd_addr_in(dec_rd),
        .opcode_in(dec_opcode), .instr_id_in(dec_instr_id),
        .pc_in(if_id_pc),
        .rs1_value_in(rf_rs1_value), .rs2_value_in(rf_rs2_value),
        .stall(pipeline_flush || stall_load_use),
        .rs1_valid_out(id_ex_rs1_valid), .rs2_valid_out(id_ex_rs2_valid), .rd_valid_out(id_ex_rd_valid),
        .imm_out(id_ex_imm),
        .rs1_addr_out(id_ex_rs1_addr), .rs2_addr_out(id_ex_rs2_addr), .rd_addr_out(id_ex_rd),
        .opcode_out(id_ex_opcode), .instr_id_out(id_ex_instr_id),
        .pc_out(id_ex_pc),
        .rs1_value_out(id_ex_rs1_value), .rs2_value_out(id_ex_rs2_value)
    );

    // ---- Forwarding ----
    wire [1:0] forward_a, forward_b;
    wire [ 4:0] ex_mem_rd;
    wire        ex_mem_rd_valid;
    wire [ 5:0] ex_mem_instr_id;
    wire [ 4:0] mem_wb_rd;
    wire        mem_wb_rd_valid;
    wire        wb_wr_en;

    forwarding_unit fwd_inst (
        .rs1_addr_ex(id_ex_rs1_addr), .rs2_addr_ex(id_ex_rs2_addr),
        .rs1_valid_ex(id_ex_rs1_valid), .rs2_valid_ex(id_ex_rs2_valid),
        .rd_addr_mem(ex_mem_rd), .rd_valid_mem(ex_mem_rd_valid), .instr_id_mem(ex_mem_instr_id),
        .rd_addr_wb(mem_wb_rd), .rd_valid_wb(mem_wb_rd_valid), .wr_en_wb(wb_wr_en),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    // ---- Execute ----
    wire [31:0] ex_exec_output;
    wire [31:0] ex_mem_addr_wire;
    wire [31:0] ex_rs1_value, ex_rs2_value;
    wire [31:0] ex_mem_exec_output;
    wire [31:0] wb_rd_value;

    execution_unit ex_inst (
        .rs1(id_ex_rs1_value), .rs2(id_ex_rs2_value),
        .imm(id_ex_imm),
        .rs1_addr(id_ex_rs1_addr), .rs2_addr(id_ex_rs2_addr),
        .opcode(id_ex_opcode), .instr_id(id_ex_instr_id),
        .rs1_valid(id_ex_rs1_valid), .rs2_valid(id_ex_rs2_valid),
        .pc_input(id_ex_pc),
        .forward_a(forward_a), .forward_b(forward_b),
        .ex_mem_result(ex_mem_exec_output),
        .mem_wb_result(wb_rd_value),
        .exec_output(ex_exec_output),
        .jump_signal(jump_signal),
        .jump_addr(jump_addr),
        .mem_addr(ex_mem_addr_wire),
        .rs1_value_out(ex_rs1_value), .rs2_value_out(ex_rs2_value),
        .flush_pipeline(execution_flush)
    );

    // ---- EX/MEM ----
    wire [31:0] ex_mem_rs1_value, ex_mem_rs2_value;
    wire [31:0] ex_mem_pc;
    wire [31:0] ex_mem_mem_addr;
    wire        ex_mem_jump_signal;
    wire [31:0] ex_mem_jump_addr;

    EX_MEM ex_mem_inst (
        .clk(clk), .rst(rst),
        .rs1_addr_in(id_ex_rs1_addr), .rs2_addr_in(id_ex_rs2_addr), .rd_addr_in(id_ex_rd),
        .rs1_value_in(ex_rs1_value), .rs2_value_in(ex_rs2_value),
        .pc_in(id_ex_pc),
        .mem_addr_in(ex_mem_addr_wire),
        .exec_output_in(ex_exec_output),
        .jump_signal_in(jump_signal), .jump_addr_in(jump_addr),
        .instr_id_in(id_ex_instr_id), .rd_valid_in(id_ex_rd_valid),
        .rs1_addr_out(), .rs2_addr_out(),
        .rd_addr_out(ex_mem_rd),
        .rs1_value_out(ex_mem_rs1_value), .rs2_value_out(ex_mem_rs2_value),
        .pc_out(ex_mem_pc),
        .mem_addr_out(ex_mem_mem_addr),
        .exec_output_out(ex_mem_exec_output),
        .jump_signal_out(ex_mem_jump_signal), .jump_addr_out(ex_mem_jump_addr),
        .instr_id_out(ex_mem_instr_id), .rd_valid_out(ex_mem_rd_valid)
    );

    // ---- Memory Unit ----
    wire        mem_wr_en, mem_rd_en;
    wire [31:0] mem_wr_data, mem_read_addr, mem_wr_addr;
    wire [ 3:0] mem_byte_en;
    wire [ 2:0] mem_load_type;

    memory_unit mem_unit_inst (
        .instr_id(ex_mem_instr_id),
        .rs2_value(ex_mem_rs2_value),
        .mem_addr(ex_mem_mem_addr),
        .wr_enable(mem_wr_en), .read_enable(mem_rd_en),
        .wr_data(mem_wr_data),
        .read_addr(mem_read_addr), .wr_addr(mem_wr_addr),
        .write_byte_enable(mem_byte_en),
        .load_type(mem_load_type)
    );

    assign module_mem_wr_en           = mem_wr_en;
    assign module_mem_rd_en           = mem_rd_en;
    assign module_write_addr          = mem_wr_addr;
    assign module_read_addr           = mem_read_addr;
    assign module_wr_data_out         = mem_wr_data;
    assign module_write_byte_enable   = mem_byte_en;
    assign module_load_type           = mem_load_type;

    // ---- Store-load forwarding ----
    // Forward-declare mem_wb wires needed by sld_inst (defined at MEM/WB section below)
    wire [ 5:0] mem_wb_instr_id;
    wire [31:0] mem_wb_mem_addr;

    wire        store_load_hazard;
    wire [31:0] forwarded_store_data;

    store_load_detector sld_inst (
        .load_instr_id(ex_mem_instr_id),
        .load_addr(ex_mem_mem_addr),
        .prev_store_instr_id(mem_wb_instr_id),
        .prev_store_addr(mem_wb_mem_addr),
        .rs2_value(ex_mem_rs2_value),
        .store_load_hazard(store_load_hazard),
        .forwarded_data(forwarded_store_data)
    );

    // ---- MEM/WB ----
    wire [31:0] mem_wb_exec_output;
    wire [31:0] mem_wb_mem_data;

    MEM_WB mem_wb_inst (
        .clk(clk), .rst(rst),
        .rs1_addr_in(), .rs2_addr_in(),
        .rd_addr_in(ex_mem_rd),
        .rs1_value_in(ex_mem_rs1_value), .rs2_value_in(ex_mem_rs2_value),
        .pc_in(ex_mem_pc),
        .mem_addr_in(ex_mem_mem_addr),
        .exec_output_in(ex_mem_exec_output),
        .jump_signal_in(ex_mem_jump_signal), .jump_addr_in(ex_mem_jump_addr),
        .instr_id_in(ex_mem_instr_id), .rd_valid_in(ex_mem_rd_valid),
        .mem_data_in(module_read_data_in),
        .store_load_hazard(store_load_hazard),
        .store_data(forwarded_store_data),
        .rs1_addr_out(), .rs2_addr_out(),
        .rd_addr_out(mem_wb_rd),
        .rs1_value_out(), .rs2_value_out(),
        .pc_out(), .mem_addr_out(mem_wb_mem_addr),
        .exec_output_out(mem_wb_exec_output),
        .jump_signal_out(), .jump_addr_out(),
        .instr_id_out(mem_wb_instr_id), .rd_valid_out(mem_wb_rd_valid),
        .mem_data_out(mem_wb_mem_data)
    );

    // ---- Writeback ----
    wire [31:0] wb_rd_addr_wire;

    writeback wb_inst (
        .rd_valid_in(mem_wb_rd_valid),
        .rd_addr_in(mem_wb_rd),
        .rd_value_in(mem_wb_exec_output),
        .mem_data_in(mem_wb_mem_data),
        .instr_id_in(mem_wb_instr_id),
        .rd_addr_out(rf_rd),
        .rd_value_out(wb_rd_value),
        .wr_en_out(wb_wr_en)
    );

    assign rf_rd_value  = wb_rd_value;
    assign rf_wr_en     = wb_wr_en;
    assign fetch_redirect = jump_signal;

endmodule
