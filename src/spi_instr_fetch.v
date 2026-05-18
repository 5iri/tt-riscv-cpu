// SPI master for instruction fetch with a tiny direct-mapped instruction cache.
// Misses take one 32-bit SPI transaction; hits are served immediately.
`default_nettype none
module spi_instr_fetch (
    input  wire        clk,
    input  wire        rst,
    input  wire        redirect,
    input  wire [31:0] pc,
    output wire [31:0] instr,
    output wire [31:0] instr_pc,
    output wire        busy,
    output reg         spi_sck,
    output reg         spi_cs_n,
    output reg         spi_mosi,
    input  wire        spi_miso
);
    localparam CACHE_LINES = 64;
    localparam CACHE_BITS  = 6;

    reg [6:0]  cnt;       // 0..127
    reg        active;
    reg [31:0] addr_latch;
    reg [31:0] data_sr;
    reg [31:0] instr_reg;
    reg [31:0] instr_pc_reg;

    reg        cache_valid [0:CACHE_LINES-1];
    reg [25:0] cache_tag   [0:CACHE_LINES-1];
    reg [31:0] cache_data  [0:CACHE_LINES-1];

    wire [CACHE_BITS-1:0] pc_index   = pc[7:2];
    wire [25:0]           pc_tag     = pc[31:6];
    wire                  cache_hit  = cache_valid[pc_index] && (cache_tag[pc_index] == pc_tag);
    wire [31:0]           cache_word = cache_data[pc_index];

    wire [CACHE_BITS-1:0] fill_index = addr_latch[7:2];
    wire [25:0]           fill_tag   = addr_latch[31:6];
    wire [31:0]           fill_word  = {data_sr[30:0], spi_miso};

    assign instr    = cache_hit ? cache_word : instr_reg;
    assign instr_pc = cache_hit ? pc : instr_pc_reg;
    assign busy     = active || (!cache_hit);

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            active    <= 1'b0;
            cnt       <= 7'd0;
            spi_cs_n  <= 1'b1;
            spi_sck   <= 1'b0;
            spi_mosi  <= 1'b0;
            instr_reg <= 32'h00000013; // NOP
            instr_pc_reg <= 32'b0;
            data_sr   <= 32'b0;
            for (i = 0; i < CACHE_LINES; i = i + 1) begin
                cache_valid[i] <= 1'b0;
                cache_tag[i]   <= 26'b0;
                cache_data[i]  <= 32'b0;
            end
        end else if (redirect) begin
            active    <= 1'b0;
            cnt       <= 7'd0;
            spi_cs_n  <= 1'b1;
            spi_sck   <= 1'b0;
            spi_mosi  <= 1'b0;
            instr_reg <= 32'h00000013;
            instr_pc_reg <= pc;
            data_sr   <= 32'b0;
        end else if (!active) begin
            if (!cache_hit) begin
                active    <= 1'b1;
                cnt       <= 7'd0;
                addr_latch <= pc;
                spi_cs_n  <= 1'b0;
                spi_sck   <= 1'b0;
                spi_mosi  <= pc[31];
                instr_reg <= 32'h00000013;
                instr_pc_reg <= pc;
                data_sr   <= 32'b0;
            end
        end else begin
            spi_sck <= cnt[0]; // SCK = cnt LSB: 0,1,0,1,...

            if (cnt < 7'd64) begin
                // Address phase (cnt 0..63 = 32 SCK cycles = 32 address bits)
                if (!cnt[0])
                    spi_mosi <= addr_latch[31 - cnt[6:1]];
            end else begin
                // Data phase (cnt 64..127 = 32 SCK cycles = 32 data bits)
                if (cnt[0])
                    data_sr <= {data_sr[30:0], spi_miso};
            end

            if (cnt == 7'd127) begin
                active                <= 1'b0;
                spi_cs_n              <= 1'b1;
                spi_sck               <= 1'b0;
                instr_reg             <= fill_word;
                instr_pc_reg          <= addr_latch;
                cache_valid[fill_index] <= 1'b1;
                cache_tag[fill_index]   <= fill_tag;
                cache_data[fill_index]  <= fill_word;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
endmodule
