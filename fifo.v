module fifo(
    clk,
    rst,
    wren,
    wdat,
    rden,
    rdat,
    rvld,
    full,
    empty
);

parameter ADDR_WIDTH = 4;
parameter DATA_WIDTH = 32;
parameter FIFO_DEPTH = 16;

input                       clk;
input                       rst;
input                       wren;
input  [DATA_WIDTH - 1 : 0] wdat;
input                       rden;
output [DATA_WIDTH - 1 : 0] rdat;
output                      rvld;
output                      full;
output                      empty;

reg [DATA_WIDTH - 1 : 0] ff_mem [FIFO_DEPTH - 1 : 0];
reg [ADDR_WIDTH : 0] wr_ptr;
reg [ADDR_WIDTH : 0] rd_ptr;
reg [DATA_WIDTH - 1 : 0] rd_data_reg;

wire [ADDR_WIDTH - 1 : 0] wr_addr;
wire [ADDR_WIDTH - 1 : 0] rd_addr;
wire wr_enb;
wire rd_enb;
wire [ADDR_WIDTH - 1 : 0] data_counter;

// Read/write address
assign rd_addr = rd_ptr[ADDR_WIDTH - 1 : 0];
assign wr_addr = wr_ptr[ADDR_WIDTH - 1 : 0];

// FIFO full, empty
assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && (wr_addr == rd_addr);
assign empty = (wr_ptr == rd_ptr);

// Enable to prevent write when full, read when empty
assign wr_enb = ~full  & wren;
assign rd_enb = ~empty & rden;

// FIFO Data counter
assign data_counter = wr_ptr - rd_ptr;

// Write data
integer i;
always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < FIFO_DEPTH - 1; i = i + 1) begin
            ff_mem[i] <= 0;
        end
        wr_ptr    <= 0;
    end
    else if (wr_enb) begin
        ff_mem[wr_addr] <= wdat;
        wr_ptr          <= wr_ptr + 1'b1;
    end
end

// Read data
reg rd_data_vld_reg;

always @(posedge clk) begin
    if (rst) begin
        rd_ptr          <= 0;
        rd_data_reg     <= 0;
        rd_data_vld_reg <= 0;
    end
    else if (rd_enb) begin
        rd_ptr          <= rd_ptr + 1'b1;
        rd_data_reg     <= ff_mem[rd_addr];
        rd_data_vld_reg <= 1'b1;
    end
    else begin
        rd_data_reg     <= 0;
        rd_data_vld_reg <= 0;
    end
end

// Read data out
assign rdat = rd_data_reg;
assign rvld = rd_data_vld_reg;

endmodule
