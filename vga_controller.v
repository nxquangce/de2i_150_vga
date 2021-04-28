module vga_controller(iRST_n,
                      iVGA_CLK,
                      oBLANK_n,
                      oHS,
                      oVS,
                      b_data,
                      g_data,
                      r_data);
input iRST_n;
input iVGA_CLK;
output oBLANK_n;
output oHS;
output oVS;
output reg [7:0] b_data;
output reg [7:0] g_data;  
output reg [7:0] r_data;                        
///////// ////                     
reg [18:0] ADDR;
reg [23:0] bgr_data;
wire VGA_CLK_n;
wire [7:0] index;
wire [23:0] bgr_data_raw;
wire cBLANK_n,cHS,cVS,rst;
////
assign rst = ~iRST_n;
video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
                              .reset(rst),
                              .blank_n(cBLANK_n),
                              .HS(cHS),
                              .VS(cVS));
////
////Addresss generator
always@(posedge iVGA_CLK,negedge iRST_n)
begin
  if (!iRST_n)
     ADDR<=19'd4;
  else if (cHS==1'b0 && cVS==1'b0)
     ADDR<=19'd4;
  else if (cBLANK_n==1'b1)
     ADDR<=ADDR+1;
end
//////////////////////////
//////INDEX addr.
assign VGA_CLK_n = ~iVGA_CLK;
img_data	img_data_inst (
	.address ( ADDR ),
	.clock ( VGA_CLK_n ),
	.q ( index )
	);
//////Color table output
img_index	img_index_inst (
	.address ( index ),
	.clock ( iVGA_CLK ),
	.q ( bgr_data_raw)
	);	
//////
//////latch valid data at falling edge;
always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw;


always@(posedge VGA_CLK_n or negedge iRST_n)
begin
	if (!iRST_n)
		begin
			b_data <= 0;
			g_data <= 0;
			r_data <= 0;
		end
	else
		begin
			b_data <= bgr_data[23:16];
			g_data <= bgr_data[15:8];
			r_data <= bgr_data[7:0];
		
		
		end

end

//assign b_data = bgr_data[23:16];
//assign g_data = bgr_data[15:8];
//assign r_data = bgr_data[7:0];
///////////////////
//////Delay the iHD, iVD,iDEN for one clock cycle;
//always@(negedge iVGA_CLK)
//begin
//  oHS<=cHS;
//  oVS<=cVS;
////  oBLANK_n<=cBLANK_n;
//end

reg [4:0] delay_bus;
reg [4:0] delay_busv;
reg [4:0] delay_bush;

always@(posedge VGA_CLK_n or negedge iRST_n)
begin
	if (!iRST_n)
		begin
			delay_bus <= 0;
			delay_busv <= 0;
			delay_bush <= 0;

		end
	else
		begin
			delay_bus <= {delay_bus[3:0],cBLANK_n};
			delay_bush <= {delay_bush[3:0],cHS};
			delay_busv <= {delay_busv[3:0],cVS};
			
			
		end
end

assign oBLANK_n = delay_bus[1];
assign oHS = delay_bush[1];
assign oVS = delay_busv[1];

endmodule
 	
















