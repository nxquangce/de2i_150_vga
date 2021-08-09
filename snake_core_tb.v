module snake_core_tb;

parameter VGA_ADDR_WIDTH    = 19;
parameter H_LOGIC_WIDTH     = 5;
parameter V_LOGIC_WIDTH     = 5;

parameter H_LOGIC_MAX       = 5'd31;
parameter V_LOGIC_MAX       = 5'd23;

parameter H_PHY_WIDTH       = 10;
parameter V_PHY_WIDTH       = 9;

parameter H_PHY_MAX         = 10'd639;
parameter V_PHY_MAX         = 9'd479;

parameter COLOR_ID_WIDTH    = 8;

localparam FF_DATA_WIDTH = 4 + (H_LOGIC_WIDTH + V_LOGIC_WIDTH) * 2 + COLOR_ID_WIDTH; // = 32

reg                          clk;
reg                          rst;
wire [FF_DATA_WIDTH - 1 : 0] snake_cmd;
wire                         snake_cmd_vld;

snake_core 
    #(
    .SNAKE_DEPTH_MAX    (128),
    .SNAKE_WIDTH        (7),
    .H_LOGIC_WIDTH      (H_LOGIC_WIDTH),
    .V_LOGIC_WIDTH      (V_LOGIC_WIDTH),
    .H_LOGIC_MAX        (H_LOGIC_MAX),
    .V_LOGIC_MAX        (V_LOGIC_MAX),
    .COLOR_ID_WIDTH     (COLOR_ID_WIDTH)
    )
uut(
    .clk                (clk),
    .rst                (rst),
    .enb                (1'b1),
    .up                 (1'b0),
    .down               (1'b0),
    .left               (1'b0),
    .right              (1'b0),
    .cmd                (snake_cmd),
    .cmd_vld            (snake_cmd_vld)
);

reg                          ff_block;
wire                         ff_full;
wire                         ff_empty;
wire                         ff_wren;
wire                         ff_rden;
wire                         ff_rvld;
wire [FF_DATA_WIDTH - 1 : 0] ff_wdat;
wire [FF_DATA_WIDTH - 1 : 0] ff_rdat;
wire                         ff_unblock;

always @(posedge clk) begin
    if (rst | ff_unblock) begin
        ff_block <= 0;
    end
    else if (ff_rden) begin
        ff_block <= 1'b1;
    end
end

assign ff_wren = snake_cmd_vld; //|vld_start_pp[1 : 0];
assign ff_wdat = snake_cmd; // cmd;
assign ff_rden = ~(ff_empty | ff_block);

fifo 
    #(
    .ADDR_WIDTH (4),
    .DATA_WIDTH (FF_DATA_WIDTH),
    .FIFO_DEPTH (16)
    )
i_fifo(
    .clk        (clk),
    .rst        (rst),
    .wren       (ff_wren),
    .wdat       (ff_wdat),
    .rden       (ff_rden),
    .rdat       (ff_rdat),
    .rvld       (ff_rvld),
    .full       (ff_full),
    .empty      (ff_empty)
);

// Update ram
// Draw super pixel
wire [H_LOGIC_WIDTH - 1 : 0]  pixel_x_logic;
wire [V_LOGIC_WIDTH - 1 : 0]  pixel_y_logic;
wire [COLOR_ID_WIDTH - 1 : 0] pixel_color;
wire                          pixel_vld;
wire                          pixel_done;

wire [VGA_ADDR_WIDTH - 1 : 0] pixel_addr;
wire [COLOR_ID_WIDTH - 1 : 0] pixel_data;
wire                          pixel_wren;

assign pixel_x_logic = ff_rdat[FF_DATA_WIDTH - 5 : FF_DATA_WIDTH - 4 - H_LOGIC_WIDTH];
assign pixel_y_logic = ff_rdat[FF_DATA_WIDTH - 5  - H_LOGIC_WIDTH : FF_DATA_WIDTH - 4 - H_LOGIC_WIDTH - V_LOGIC_WIDTH];
assign pixel_color = ff_rdat[FF_DATA_WIDTH - 5 - H_LOGIC_WIDTH - V_LOGIC_WIDTH : FF_DATA_WIDTH - 4 - H_LOGIC_WIDTH - V_LOGIC_WIDTH - COLOR_ID_WIDTH];
assign pixel_vld = (ff_rdat[FF_DATA_WIDTH - 1 : FF_DATA_WIDTH - 4] == 4'h0) & ff_rvld;

draw_superpixel 
    #(
    .SPIXEL_X_WIDTH    (H_LOGIC_WIDTH),
    .SPIXEL_Y_WIDTH    (V_LOGIC_WIDTH),
    .SPIXEL_X_MAX      (H_LOGIC_MAX),
    .SPIXEL_Y_MAX      (V_LOGIC_MAX),
    .PIXEL_X_WIDTH     (H_PHY_WIDTH),
    .PIXEL_Y_WIDTH     (V_PHY_WIDTH),
    .PIXEL_X_MAX       (H_PHY_MAX),
    .PIXEL_Y_MAX       (V_PHY_MAX)
    )
pixel (
    .clk        (clk),
    .rst        (rst),
    // USER IF
    .x          (pixel_x_logic),
    .y          (pixel_y_logic),
    .idata      (pixel_color),
    .idata_vld  (pixel_vld),
    .odone      (pixel_done),
    // VGA RAM IF
    .oaddr      (pixel_addr),
    .odata      (pixel_data),
    .owren      (pixel_wren)
    );


// Draw rectangle
wire [H_LOGIC_WIDTH - 1 : 0]  rect_x0_logic;
wire [V_LOGIC_WIDTH - 1 : 0]  rect_y0_logic;
wire [H_LOGIC_WIDTH - 1 : 0]  rect_x1_logic;
wire [V_LOGIC_WIDTH - 1 : 0]  rect_y1_logic;
wire [COLOR_ID_WIDTH - 1 : 0] rect_color;
wire                          rect_vld;
wire                          rect_done;

wire [VGA_ADDR_WIDTH - 1 : 0] rect_addr;
wire [COLOR_ID_WIDTH - 1 : 0] rect_data;
wire                          rect_wren;

assign rect_x0_logic = ff_rdat[FF_DATA_WIDTH - 5 : FF_DATA_WIDTH - 4 - H_LOGIC_WIDTH];
assign rect_y0_logic = ff_rdat[FF_DATA_WIDTH - 5  - H_LOGIC_WIDTH : FF_DATA_WIDTH - 4 - H_LOGIC_WIDTH - V_LOGIC_WIDTH];
assign rect_x1_logic = ff_rdat[FF_DATA_WIDTH - 5  - H_LOGIC_WIDTH - V_LOGIC_WIDTH : FF_DATA_WIDTH - 4 - H_LOGIC_WIDTH * 2 - V_LOGIC_WIDTH];
assign rect_y1_logic = ff_rdat[FF_DATA_WIDTH - 5  - H_LOGIC_WIDTH * 2 - V_LOGIC_WIDTH : FF_DATA_WIDTH - 4 - H_LOGIC_WIDTH * 2 - V_LOGIC_WIDTH * 2];
assign rect_color = ff_rdat[FF_DATA_WIDTH - 5  - H_LOGIC_WIDTH * 2 - V_LOGIC_WIDTH * 2 : 0];
assign rect_vld = (ff_rdat[FF_DATA_WIDTH - 1 : FF_DATA_WIDTH - 4] == 4'h1) & ff_rvld;

draw_rectangle_sp
    #(
    .SPIXEL_X_WIDTH    (H_LOGIC_WIDTH),
    .SPIXEL_Y_WIDTH    (V_LOGIC_WIDTH),
    .SPIXEL_X_MAX      (H_LOGIC_MAX),
    .SPIXEL_Y_MAX      (V_LOGIC_MAX),
    .PIXEL_X_WIDTH     (H_PHY_WIDTH),
    .PIXEL_Y_WIDTH     (V_PHY_WIDTH),
    .PIXEL_X_MAX       (H_PHY_MAX),
    .PIXEL_Y_MAX       (V_PHY_MAX)
    )
rectangle_sp (
    .clk                (clk),
    .rst                (rst),
    // USER IF
    .x0                 (rect_x0_logic),
    .y0                 (rect_y0_logic),
    .x1                 (rect_x1_logic),
    .y1                 (rect_y1_logic),
    .idata              (rect_color),
    .idata_vld          (rect_vld),
    .odone              (rect_done),
    // VGA RAM IF
    .oaddr              (rect_addr),
    .odata              (rect_data),
    .owren              (rect_wren)
    );

wire    [H_PHY_WIDTH - 1 : 0] rect_px_x0_physic;
wire    [V_PHY_WIDTH - 1 : 0] rect_px_y0_physic;
wire    [H_PHY_WIDTH - 1 : 0] rect_px_x1_physic;
wire    [V_PHY_WIDTH - 1 : 0] rect_px_y1_physic;
wire [COLOR_ID_WIDTH - 1 : 0] rect_px_color;
wire                  [1 : 0] rect_px_mode;
wire                          rect_px_vld;
wire                          rect_px_half;
wire                          rect_px_done;

wire [VGA_ADDR_WIDTH - 1 : 0] rect_px_addr;
wire [COLOR_ID_WIDTH - 1 : 0] rect_px_data;
wire                          rect_px_wren;

assign rect_px_x0_physic = ff_rdat[FF_DATA_WIDTH - 5 : FF_DATA_WIDTH - 4 - H_PHY_WIDTH];
assign rect_px_y0_physic = ff_rdat[FF_DATA_WIDTH - 5  - H_PHY_WIDTH : FF_DATA_WIDTH - 4 - H_PHY_WIDTH - V_PHY_WIDTH];
assign rect_px_color     = ff_rdat[FF_DATA_WIDTH - 5  - H_PHY_WIDTH - V_PHY_WIDTH : 1];
assign rect_px_vld       = (ff_rdat[FF_DATA_WIDTH - 1 : FF_DATA_WIDTH - 4] == 4'h9) & ff_rvld;
assign rect_px_mode      = {1'b0, ff_rdat[0]};
assign rect_px_half      = (~ff_rdat[0]) & rect_px_vld;

draw_rectangle
    #(
    .PIXEL_X_WIDTH      (H_PHY_WIDTH),
    .PIXEL_Y_WIDTH      (V_PHY_WIDTH),
    .PIXEL_X_MAX        (H_PHY_MAX),
    .PIXEL_Y_MAX        (V_PHY_MAX)
    )
rectangle (
    .clk                (clk),
    .rst                (rst),
    // USER IF
    .x0                 (rect_px_x0_physic),
    .y0                 (rect_px_y0_physic),
    .x1                 (rect_px_x0_physic),
    .y1                 (rect_px_y0_physic),
    .mode               (rect_px_mode),
    .idata              (rect_px_color),
    .idata_vld          (rect_px_vld),
    .odone              (rect_px_done),
    // VGA RAM IF
    .oaddr              (rect_px_addr),
    .odata              (rect_px_data),
    .owren              (rect_px_wren)
    );

assign ff_unblock = pixel_done | rect_done | rect_px_done | rect_px_half;

initial begin
    clk <= 0;

    forever begin
        #5 clk <= ~clk;
    end
end

initial begin
    rst <= 1'b0;

    #20 rst <= 1'b1;
    #20 rst <= 1'b0;
end


endmodule