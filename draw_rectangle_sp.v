module draw_rectangle_sp(
    clk,
    rst,
    // USER IF
    x0,
    y0,
    x1,
    y1,
    idata,
    idata_vld,
    odone,
    // VGA RAM IF
    oaddr,
    odata,
    owren
);

parameter SPIXEL_X_WIDTH    = 6;
parameter SPIXEL_Y_WIDTH    = 6;
parameter SPIXEL_X_MAX      = 6'd63;
parameter SPIXEL_Y_MAX      = 6'd47;

parameter PIXEL_X_WIDTH     = 10;
parameter PIXEL_Y_WIDTH     = 9;
parameter PIXEL_X_MAX       = 10'd639;
parameter PIXEL_Y_MAX       = 9'd479;

parameter VGA_ADDR_WIDTH    = 19;
parameter COLOR_ID_WIDTH    = 8;

input                           clk;
input                           rst;
input  [SPIXEL_X_WIDTH - 1 : 0] x0;
input  [SPIXEL_Y_WIDTH - 1 : 0] y0;
input  [SPIXEL_X_WIDTH - 1 : 0] x1;
input  [SPIXEL_Y_WIDTH - 1 : 0] y1;
input  [COLOR_ID_WIDTH - 1 : 0] idata;
input                           idata_vld;
output                          odone;
output [VGA_ADDR_WIDTH - 1 : 0] oaddr;
output [COLOR_ID_WIDTH - 1 : 0] odata;
output                          owren;

reg [PIXEL_X_WIDTH - 1 : 0] x0_logic;
reg [PIXEL_Y_WIDTH - 1 : 0] y0_logic;
reg [PIXEL_X_WIDTH - 1 : 0] x1_logic;
reg [PIXEL_Y_WIDTH - 1 : 0] y1_logic;

wire [PIXEL_X_WIDTH - 1 : 0] tlx0_physic;
wire [PIXEL_Y_WIDTH - 1 : 0] tly0_physic;
wire [PIXEL_X_WIDTH - 1 : 0] brx0_physic;
wire [PIXEL_Y_WIDTH - 1 : 0] bry0_physic;

wire [PIXEL_X_WIDTH - 1 : 0] tlx1_physic;
wire [PIXEL_Y_WIDTH - 1 : 0] tly1_physic;
wire [PIXEL_X_WIDTH - 1 : 0] brx1_physic;
wire [PIXEL_Y_WIDTH - 1 : 0] bry1_physic;

superpixel2pixel 
    #(
    .SPIXEL_X_WIDTH (SPIXEL_X_WIDTH),
    .SPIXEL_Y_WIDTH (SPIXEL_Y_WIDTH),
    .SPIXEL_X_MAX   (SPIXEL_X_MAX),
    .SPIXEL_Y_MAX   (SPIXEL_Y_MAX),
    .PIXEL_X_WIDTH  (PIXEL_X_WIDTH),
    .PIXEL_Y_WIDTH  (PIXEL_Y_WIDTH),
    .PIXEL_X_MAX    (PIXEL_X_MAX),
    .PIXEL_Y_MAX    (PIXEL_Y_MAX)
    )
convert0
    (
    .x              (x0_logic),
    .y              (y0_logic),
    .tlx            (tlx0_physic),
    .tly            (tly0_physic),
    .brx            (brx0_physic),
    .bry            (bry0_physic)
    );

superpixel2pixel 
    #(
    .SPIXEL_X_WIDTH (SPIXEL_X_WIDTH),
    .SPIXEL_Y_WIDTH (SPIXEL_Y_WIDTH),
    .SPIXEL_X_MAX   (SPIXEL_X_MAX),
    .SPIXEL_Y_MAX   (SPIXEL_Y_MAX),
    .PIXEL_X_WIDTH  (PIXEL_X_WIDTH),
    .PIXEL_Y_WIDTH  (PIXEL_Y_WIDTH),
    .PIXEL_X_MAX    (PIXEL_X_MAX),
    .PIXEL_Y_MAX    (PIXEL_Y_MAX)
    )
convert1
    (
    .x              (x1_logic),
    .y              (y1_logic),
    .tlx            (tlx1_physic),
    .tly            (tly1_physic),
    .brx            (brx1_physic),
    .bry            (bry1_physic)
    );

reg [PIXEL_X_WIDTH - 1 : 0] x_physic;
reg [PIXEL_Y_WIDTH - 1 : 0] y_physic;

reg [COLOR_ID_WIDTH - 1 : 0] data;
reg                          wren;
reg                          vld_start;

reg run;

always @(posedge clk) begin
    if (rst) begin
        data <= 0;
        vld_start <= 0;
        x0_logic <= 0;
        y0_logic <= 0;
        x1_logic <= 0;
        y1_logic <= 0;
    end
    else if (idata_vld) begin
        data <= idata;
        vld_start <= 1;
        x0_logic <= x0;
        y0_logic <= y0;
        x1_logic <= x1;
        y1_logic <= y1;
    end
    else begin
        vld_start <= 0;
    end
end

always @(posedge clk) begin
    if (rst | done) begin
        run <= 1'b0;
    end
    else if (vld_start) begin
        run <= 1'b1;
    end
end

always @(posedge clk) begin
    if (rst | done) begin
        x_physic <= 0;
        y_physic <= 0;
        wren <= 0;
    end
    else if (vld_start) begin
        x_physic <= tlx0_physic;
        y_physic <= tly0_physic;
        wren <= 1'b1;
    end
    else if (run) begin
        x_physic <= (x_physic == brx1_physic) ? tlx0_physic : x_physic + 1'b1;
        y_physic <= (x_physic == brx1_physic) ? y_physic + 1'b1 : y_physic;
    end
end

wire [VGA_ADDR_WIDTH - 1 : 0] addr;

pixel2addr p2a(
    .x      (x_physic),
    .y      (y_physic),
    .addr   (addr)
);

reg done_reg;
always @(posedge clk) begin
    done_reg <= (rst) ? 0 : done;
end

assign done = (x_physic == (brx1_physic)) && (y_physic == bry1_physic);
assign odone = done_reg;

assign oaddr = (wren) ? addr : 0;
assign odata = (wren) ? data : 0;
assign owren = wren;

endmodule