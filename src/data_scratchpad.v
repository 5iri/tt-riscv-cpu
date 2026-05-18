// 256-byte synchronous data RAM for CPU stack/variables.
`default_nettype none
module data_scratchpad (
    input  wire        clk,
    input  wire        wr_en,
    input  wire        rd_en,
    input  wire [31:0] addr,
    input  wire [31:0] wr_data,
    input  wire [ 3:0] byte_en,
    input  wire [ 2:0] load_type,
    output reg  [31:0] rd_data
);
    reg [31:0] mem [0:63]; // 64 words = 256 bytes

    integer i;
    initial begin
        for (i = 0; i < 64; i = i + 1) mem[i] = 32'b0;
    end

    wire [5:0] widx = addr[7:2];

    always @(posedge clk) begin
        if (wr_en) begin
            if (byte_en[0]) mem[widx][ 7: 0] <= wr_data[ 7: 0];
            if (byte_en[1]) mem[widx][15: 8] <= wr_data[15: 8];
            if (byte_en[2]) mem[widx][23:16] <= wr_data[23:16];
            if (byte_en[3]) mem[widx][31:24] <= wr_data[31:24];
        end
    end

    always @(*) begin
        if (rd_en) begin
            case (load_type)
                3'b000: rd_data = {{24{mem[widx][7]}},  mem[widx][ 7:0]};  // LB
                3'b001: rd_data = {{16{mem[widx][15]}}, mem[widx][15:0]};  // LH
                3'b010: rd_data = mem[widx];                                // LW
                3'b100: rd_data = {24'b0, mem[widx][ 7:0]};                // LBU
                3'b101: rd_data = {16'b0, mem[widx][15:0]};                // LHU
                default: rd_data = 32'b0;
            endcase
        end else
            rd_data = 32'b0;
    end

    wire _unused = &{1'b0, addr[31:8], addr[1:0]};
endmodule
