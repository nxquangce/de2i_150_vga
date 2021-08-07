module snake_prey(
    clk,
    rst,
    enb,
    valid,
    preyx,
    preyy
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

reg [15 : 0] random_reg;

always @(posedge clk) begin
    if (rst) begin
        random_reg <= 16'hfff0;
    end
    else begin
        random_reg[0] <= random_reg[15] + random_reg[11] + random_reg[2] + random_reg[0];
        random_reg[15 : 1] <= random_reg[14 : 0];
    end
end

reg  [H_LOGIC_WIDTH + V_LOGIC_WIDTH - 1 : 0] prey_reg;
always @(posedge clk) begin
    if (rst) begin
        prey_reg <= 0;
    end
    else if (enb & valid) begin
        prey_reg <= random_reg[H_LOGIC_WIDTH + V_LOGIC_WIDTH - 1 : 0];
    end
end

assign {preyx, preyy} = prey_reg;

endmodule