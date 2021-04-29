module de2i_150_vga(
    CLOCK_50,
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

parameter H_LOGIC_MAX       = 6'd31;
parameter V_LOGIC_MAX       = 6'd23;

parameter H_PHY_WIDTH     = 10;
parameter V_PHY_WIDTH     = 9;

parameter H_PHY_MAX       = 10'd639;
parameter V_PHY_MAX       = 9'd479;

parameter COLOR_ID_WIDTH   = 8;

input        CLOCK_50;
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

assign clk = CLOCK_50;
assign rst = ~DLY_RST;

Reset_Delay r0	(
    .iCLK(clk),
    .oRESET(DLY_RST),
    .iRST_n(KEY[0]) 	
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

// Update interval time = 0.5s
assign vld = (vld_cnt == VLD_0_5HZ_CNT_MAX);
assign vld_start = (vld_cnt == 25'b0);
always @(posedge clk) begin
    if (!DLY_RST) begin
        vld_cnt <= 0;
    end
    else begin
        vld_cnt <= (vld) ? 0 : vld_cnt + 1'b1;
    end
end

// Update superpixel position
reg init;

always @(posedge clk) begin
    if (!DLY_RST) begin
        x_logic <= H_LOGIC_MAX;
        y_logic <= V_LOGIC_MAX;
        oldx_logic <= 0;
        oldy_logic <= 0;
    end
    else if (vld) begin
        x_logic <= (x_logic == H_LOGIC_MAX) ? 0 : x_logic + 1'b1;
        y_logic <= ((y_logic == V_LOGIC_MAX) && (x_logic == H_LOGIC_MAX)) ? 0 : 
                   (x_logic == H_LOGIC_MAX) ? y_logic + 1'b1 : y_logic;
        // x_logic <= 1;
        // y_logic <= 1;

        oldx_logic <= x_logic;
        oldy_logic <= y_logic;
    end
end

// Update ram
reg run;
// reg srun;
wire done;
wire [H_PHY_WIDTH - 1 : 0] tlx_physic;
wire [V_PHY_WIDTH - 1 : 0] tly_physic;
wire [H_PHY_WIDTH - 1 : 0] brx_physic;
wire [V_PHY_WIDTH - 1 : 0] bry_physic;
wire [H_PHY_WIDTH - 1 : 0] oldtlx_physic;
wire [V_PHY_WIDTH - 1 : 0] oldtly_physic;
wire [H_PHY_WIDTH - 1 : 0] oldbrx_physic;
wire [V_PHY_WIDTH - 1 : 0] oldbry_physic;

wire [H_LOGIC_WIDTH - 1 : 0]  pixel_x_logic;
wire [V_LOGIC_WIDTH - 1 : 0]  pixel_y_logic;
wire [COLOR_ID_WIDTH - 1 : 0] pixel_color;
wire                          pixel_vld;
wire                          pixel_done;

draw_superpixel 
    #(
    .SPIXEL_X_WIDTH    (H_LOGIC_WIDTH),
    .SPIXEL_Y_WIDTH    (V_LOGIC_WIDTH),
    .SPIXEL_X_MAX      (H_LOGIC_MAX + 1),
    .SPIXEL_Y_MAX      (V_LOGIC_MAX + 1),
    .PIXEL_X_WIDTH     (H_PHY_WIDTH),
    .PIXEL_Y_WIDTH     (V_PHY_WIDTH),
    .PIXEL_X_MAX       (H_PHY_MAX + 1),
    .PIXEL_Y_MAX       (V_PHY_MAX + 1)
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
    .oaddr      (addr),
    .odata      (data),
    .owren      (wren)
    );

reg srun;
reg old_vld;

assign pixel_x_logic = (srun) ? x_logic : oldx_logic;
assign pixel_y_logic = (srun) ? y_logic : oldy_logic;
assign pixel_color = (srun) ? 8'h0f : 8'hff;
assign pixel_vld = vld_start | old_vld;

always @(posedge clk) begin
    if (rst) begin
        srun <= 0;
        old_vld <= 0;
    end
    else if (pixel_done) begin
        srun <= ~srun;
        old_vld <= ~srun;
    end
    else begin
        old_vld <= 0;
    end
end

endmodule 