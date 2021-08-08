module snake_prey(
    clk,
    rst,
    enb,
    valid,
    preyx,
    preyy,
    prey_vld
);

parameter H_LOGIC_WIDTH     = 5;
parameter V_LOGIC_WIDTH     = 5;
parameter H_LOGIC_MAX       = 5'd31;
parameter V_LOGIC_MAX       = 5'd23;

input clk;
input rst;
input enb;
input valid;
output [H_LOGIC_WIDTH - 1 : 0] preyx;
output [V_LOGIC_WIDTH - 1 : 0] preyy;
output                      prey_vld;

reg init;
reg [15 : 0] random_reg;

// always @(posedge clk) begin
//     if (rst) begin
//         init <= 1;
//     end
//     else if (valid) begin
//         init <= 0;
//     end
// end

always @(posedge clk) begin
    if (rst) begin
        random_reg <= 16'hfff0;
    end
    else begin
        random_reg[0] <= random_reg[15] ^ random_reg[11] ^ random_reg[2] ^ random_reg[0];
        random_reg[15 : 1] <= random_reg[14 : 0];
    end
end

reg [H_LOGIC_WIDTH - 1 : 0] preyx_reg;
reg [V_LOGIC_WIDTH - 1 : 0] preyy_reg;
reg                         prey_vld_reg;
always @(posedge clk) begin
    if (rst) begin
        preyx_reg <= 5'd10;
        preyy_reg <= 5'd10;
    end
    else if (enb & valid) begin
        preyx_reg <= random_reg[H_LOGIC_WIDTH + V_LOGIC_WIDTH - 1 : V_LOGIC_WIDTH];
        preyy_reg <= (random_reg[V_LOGIC_WIDTH - 1 : 0] > V_LOGIC_MAX) ? V_LOGIC_MAX : random_reg[V_LOGIC_WIDTH - 1 : 0];
    end
end

always @(posedge clk) begin
    prey_vld_reg <= valid;
end

assign preyx = preyx_reg;
assign preyy = preyy_reg;
assign prey_vld = prey_vld_reg;

endmodule