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
parameter SPIXEL_X_MAX      = 64;
parameter SPIXEL_Y_MAX      = 48;
parameter PIXEL_X_WIDTH     = 10;
parameter PIXEL_Y_WIDTH     = 9;
parameter PIXEL_X_MAX       = 640;
parameter PIXEL_Y_MAX       = 480;

localparam SPIXEL_PHY       = PIXEL_X_MAX / SPIXEL_X_MAX;

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