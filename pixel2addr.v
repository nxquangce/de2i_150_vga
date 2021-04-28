module pixel2addr(
    x,
    y,
    addr
);

parameter VGA_ADDR_WIDTH  = 19;
parameter H_PHY_WIDTH     = 10;
parameter V_PHY_WIDTH     = 9;
parameter H_PHY_MAX       = 10'd639;
parameter V_PHY_MAX       = 9'd479;

input     [H_PHY_WIDTH - 1 : 0] x;
input     [V_PHY_WIDTH - 1 : 0] y;
output [VGA_ADDR_WIDTH - 1 : 0] addr;

assign addr = y * (H_PHY_MAX + 10'd1) + x + 19'd2;

endmodule