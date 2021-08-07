module superpixel2pixel (
    x,
    y,
    tlx,
    tly,
    brx,
    bry
);

parameter SPIXEL_X_WIDTH    = 6;
parameter SPIXEL_Y_WIDTH    = 6;
parameter SPIXEL_X_MAX      = 63;
parameter SPIXEL_Y_MAX      = 47;
parameter PIXEL_X_WIDTH     = 10;
parameter PIXEL_Y_WIDTH     = 9;
parameter PIXEL_X_MAX       = 639;
parameter PIXEL_Y_MAX       = 479;

localparam PIXEL_X_MAX_1    = PIXEL_X_MAX + 1;
localparam SPIXEL_X_MAX_1   = SPIXEL_X_MAX + 1;
localparam SPIXEL_PHY       = PIXEL_X_MAX_1 / SPIXEL_X_MAX_1;

input [SPIXEL_X_WIDTH - 1 : 0] x;
input [SPIXEL_Y_WIDTH - 1 : 0] y;
output [PIXEL_X_WIDTH - 1 : 0] tlx;
output [PIXEL_Y_WIDTH - 1 : 0] tly;
output [PIXEL_X_WIDTH - 1 : 0] brx;
output [PIXEL_Y_WIDTH - 1 : 0] bry;

assign tlx = x * SPIXEL_PHY;
assign tly = y * SPIXEL_PHY;
assign brx = tlx + (SPIXEL_PHY - 1);
assign bry = tly + (SPIXEL_PHY - 1);

endmodule