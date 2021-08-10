module draw_rectangle(
    clk,
    rst,
    // USER IF
    x0,
    y0,
    x1,
    y1,
    mode,
    idata,
    idata_vld,
    odone,
    // VGA RAM IF
    oaddr,
    odata,
    owren
);

parameter PIXEL_X_WIDTH     = 10;
parameter PIXEL_Y_WIDTH     = 9;
parameter PIXEL_X_MAX       = 10'd639;
parameter PIXEL_Y_MAX       = 9'd479;

parameter VGA_ADDR_WIDTH    = 19;
parameter COLOR_ID_WIDTH    = 8;

input                           clk;
input                           rst;
input   [PIXEL_X_WIDTH - 1 : 0] x0;
input   [PIXEL_Y_WIDTH - 1 : 0] y0;
input   [PIXEL_X_WIDTH - 1 : 0] x1;
input   [PIXEL_Y_WIDTH - 1 : 0] y1;
input                   [1 : 0] mode;
input  [COLOR_ID_WIDTH - 1 : 0] idata;
input                           idata_vld;
output                          odone;
output [VGA_ADDR_WIDTH - 1 : 0] oaddr;
output [COLOR_ID_WIDTH - 1 : 0] odata;
output                          owren;

reg [PIXEL_X_WIDTH - 1 : 0] x0_physic;
reg [PIXEL_Y_WIDTH - 1 : 0] y0_physic;
reg [PIXEL_X_WIDTH - 1 : 0] x1_physic;
reg [PIXEL_Y_WIDTH - 1 : 0] y1_physic;

reg [PIXEL_X_WIDTH - 1 : 0] x_physic;
reg [PIXEL_Y_WIDTH - 1 : 0] y_physic;

reg [COLOR_ID_WIDTH - 1 : 0] data;
reg                          wren;
reg                          vld_start;
reg                          done_reg;

reg run;
wire done;

always @(posedge clk) begin
    if (rst) begin
        data <= 0;
        vld_start <= 0;
        x0_physic <= 0;
        y0_physic <= 0;
        x1_physic <= 0;
        y1_physic <= 0;
    end
    else if (idata_vld) begin
        case(mode)
            2'b00: begin
                data <= idata;
                vld_start <= 0;
                x0_physic <= x0;
                y0_physic <= y0;
            end
            2'b01: begin
                data <= idata;
                vld_start <= 1;
                x1_physic <= x1;
                y1_physic <= y1;
            end
            default: begin
                data <= idata;
                vld_start <= 1;
                x0_physic <= x0;
                y0_physic <= y0;
                x1_physic <= x1;
                y1_physic <= y1;
            end
        endcase
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
        x_physic <= x0_physic;
        y_physic <= y0_physic;
        wren <= 1'b1;
    end
    else if (run) begin
        x_physic <= (x_physic == x1_physic) ? x0_physic : x_physic + 1'b1;
        y_physic <= (x_physic == x1_physic) ? y_physic + 1'b1 : y_physic;
    end
end

wire [VGA_ADDR_WIDTH - 1 : 0] addr;

pixel2addr p2a(
    .x      (x_physic),
    .y      (y_physic),
    .addr   (addr)
);

always @(posedge clk) begin
    done_reg <= (rst) ? 0 : done;
end

assign done = (x_physic == (x1_physic)) && (y_physic == y1_physic) & run;
assign odone = done_reg;

assign oaddr = (wren) ? addr : 0;
assign odata = (wren) ? data : 0;
assign owren = wren;

endmodule