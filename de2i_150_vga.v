module de2i_150_vga(
    CLOCK_50,
    SW,
    KEY,
    VGA_B,
    VGA_BLANK_N,
    VGA_CLK,
    VGA_G,
    VGA_HS,
    VGA_R,
    VGA_SYNC_N,
    VGA_VS	
);

parameter VGA_ADDR_WIDTH    = 19;
parameter H_LOGIC_WIDTH     = 5;
parameter V_LOGIC_WIDTH     = 5;

parameter H_LOGIC_MAX       = 5'd31;
parameter V_LOGIC_MAX       = 5'd23;

parameter H_PHY_WIDTH     = 10;
parameter V_PHY_WIDTH     = 9;

parameter H_PHY_MAX       = 10'd639;
parameter V_PHY_MAX       = 9'd479;

parameter COLOR_ID_WIDTH   = 8;

input        CLOCK_50;
input [17:0] SW;
input  [3:0] KEY;
output [7:0] VGA_B;
output       VGA_BLANK_N;
output       VGA_CLK;
output [7:0] VGA_G;
output       VGA_HS;
output [7:0] VGA_R;
output       VGA_SYNC_N;
output       VGA_VS;


wire		VGA_CTRL_CLK;
wire  [9:0]	mVGA_R;
wire  [9:0]	mVGA_G;
wire  [9:0]	mVGA_B;
wire [19:0]	mVGA_ADDR;
wire		DLY_RST;

//	For VGA Controller
wire        mVGA_CLK;
wire  [9:0] mRed;
wire  [9:0] mGreen;
wire  [9:0] mBlue;
wire        VGA_Read;	//	VGA data request

wire  [9:0] recon_VGA_R;
wire  [9:0] recon_VGA_G;
wire  [9:0] recon_VGA_B;

wire clk;
wire rst;
wire vga_rst_n;

// Detect key press
wire [3:0] key;
edge_detect key_right   (clk, 2'b10, KEY[0], key[0]);
edge_detect key_down    (clk, 2'b10, KEY[1], key[1]);
edge_detect key_up      (clk, 2'b10, KEY[2], key[2]);
edge_detect key_left    (clk, 2'b10, KEY[3], key[3]);

assign clk = CLOCK_50;
assign rst = SW[1] & key[0];
assign vga_rst_n = (~SW[0]) | KEY[0];

Reset_Delay r0	(
    .iCLK(clk),
    .oRESET(DLY_RST),
    .iRST_n(vga_rst_n)
    );

reg vga_clk_reg;
always @(posedge clk)
	vga_clk_reg = !vga_clk_reg;

assign VGA_CTRL_CLK = vga_clk_reg;

//	VGA Controller
//assign VGA_BLANK_N = !cDEN;
assign VGA_CLK = ~VGA_CTRL_CLK;


wire [VGA_ADDR_WIDTH - 1 : 0] addr;
wire [COLOR_ID_WIDTH - 1 : 0] data;
wire                          wren;

vga_controller_mod u4(
    .iRST_n     (DLY_RST),
    .iVGA_CLK   (VGA_CTRL_CLK),
    .iclk       (clk),
    .iwren      (wren),
    .idata      (data),
    .iaddr      (addr),
    .oBLANK_n   (VGA_BLANK_N),
    .oHS        (VGA_HS),
    .oVS        (VGA_VS),
    .b_data     (VGA_B),
    .g_data     (VGA_G),
    .r_data     (VGA_R)
    );

//// Display a superpixel move left to right, top to down
reg [H_LOGIC_WIDTH - 1 : 0] oldx_logic;
reg [V_LOGIC_WIDTH - 1 : 0] oldy_logic;

reg [H_LOGIC_WIDTH - 1 : 0] x_logic;
reg [V_LOGIC_WIDTH - 1 : 0] y_logic;

reg [H_PHY_WIDTH - 1 : 0] x_physic;
reg [V_PHY_WIDTH - 1 : 0] y_physic;

localparam VLD_1HZ_CNT_MAX = 25'd24999999;
localparam VLD_0_5HZ_CNT_MAX = 25'd12499999;
reg  [24:0] vld_cnt;
wire        vld;
wire        vld_start;
reg [3 : 0] vld_start_pp;

// Update interval time = 0.5s
assign vld = (vld_cnt == VLD_1HZ_CNT_MAX);
assign vld_start = (vld_cnt == 25'b0);

always @(posedge clk) begin
    if (rst) begin
        vld_cnt <= 0;
        vld_start_pp <= 0;
    end
    else begin
        vld_cnt <= (vld) ? 0 : vld_cnt + 1'b1;
        vld_start_pp[0] <= vld_start;
        vld_start_pp[3 : 1] <= vld_start_pp[2 : 0];
    end
end

// Update superpixel position
always @(posedge clk) begin
    if (rst) begin
        x_logic <= H_LOGIC_MAX;
        y_logic <= V_LOGIC_MAX;
        oldx_logic <= 0;
        oldy_logic <= 0;
    end
    else if (vld) begin
        x_logic <= (x_logic == H_LOGIC_MAX) ? 0 : x_logic + 1'b1;
        y_logic <= ((y_logic == V_LOGIC_MAX) && (x_logic == H_LOGIC_MAX)) ? 0 : 
                   (x_logic == H_LOGIC_MAX) ? y_logic + 1'b1 : y_logic;

        oldx_logic <= x_logic;
        oldy_logic <= y_logic;
    end
end

localparam FF_DATA_WIDTH = 4 + (H_LOGIC_WIDTH + V_LOGIC_WIDTH) * 2 + COLOR_ID_WIDTH; // = 32
reg [FF_DATA_WIDTH - 1 : 0] cmd;

always @(posedge clk) begin
    if (rst) begin
        cmd <= 0;
    end
    else begin
        if (vld_start) begin
            cmd <= ((x_logic == 5) & (y_logic == 5)) ? 
                    {4'h1, 5'd10, 5'd10, 5'd20, 5'd14, 8'haa } :
                    {4'h0, x_logic, y_logic, 8'h0f, 10'b0};
        end
        else begin
            cmd <= {4'h0, oldx_logic, oldy_logic, 8'hff, 10'b0};
        end
    end
end

wire [FF_DATA_WIDTH - 1 : 0] snake_cmd;
wire                         snake_cmd_vld;

snake_core snake_game(
    .clk        (clk),
    .rst        (rst),
    .enb        (1'b1),
    .up         (key[2]),
    .down       (key[1]),
    .left       (key[3]),
    .right      (key[0]),
    .cmd        (snake_cmd),
    .cmd_vld    (snake_cmd_vld)
);

reg                          ff_block;
wire                         ff_full;
wire                         ff_empty;
wire                         ff_wren;
wire                         ff_rden;
wire                         ff_rvld;
wire [FF_DATA_WIDTH - 1 : 0] ff_wdat;
wire [FF_DATA_WIDTH - 1 : 0] ff_rdat;

always @(posedge clk) begin
    if (rst | pixel_done | rect_done) begin
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
pixel
    (
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
rectangle_sp
    (
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

assign addr = pixel_addr | rect_addr;
assign data = pixel_data | rect_data;
assign wren = pixel_wren | rect_wren;

endmodule 