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

reg  [H_LOGIC_WIDTH + V_LOGIC_WIDTH - 1 : 0] counter;
wire [H_LOGIC_WIDTH + V_LOGIC_WIDTH - 1 : 0] random_cnt;

always @(posedge clk) begin
    if (rst) begin
        counter <= 0;
    end
    else begin
        counter <= counter + 1'b1;
    end
end

assign random_cnt = {counter[2], counter[5:3], counter[9], counter[1:0], counter[4], counter[8:6]};

reg  [H_LOGIC_WIDTH + V_LOGIC_WIDTH - 1 : 0] prey_reg;
always @(posedge clk) begin
    if (rst) begin
        prey_reg <= 0;
    end
    else if (enb & valid) begin
        prey_reg <= random_cnt;
    end
end

assign {preyx, preyy} = prey_reg;

endmodule