module snake_body(
    clk,
    rst,
    enb,
    direction,
    valid,
    snake_score,
    snake_lose,
    snake_headx,
    snake_heady,
    snake_tailx,
    snake_taily,
    preyx,
    preyy
);

parameter SNAKE_DEPTH_MAX   = 128;
parameter SNAKE_WIDTH       = 7;
parameter H_LOGIC_WIDTH     = 5;
parameter V_LOGIC_WIDTH     = 5;
parameter H_LOGIC_MAX       = 5'd31;
parameter V_LOGIC_MAX       = 5'd23;


parameter DIRECTION_WIDTH   = 2;
parameter DIR_UP            = 2'b00;
parameter DIR_DOWN          = 2'b11;
parameter DIR_LEFT          = 2'b10;
parameter DIR_RIGHT         = 2'b01;

localparam FF_DATA_WIDTH    = H_LOGIC_WIDTH + V_LOGIC_WIDTH;

input                           clk;
input                           rst;
input                           enb;
input [DIRECTION_WIDTH - 1 : 0] direction;
input                           valid;
output                          snake_score;
output                          snake_lose;
output  [H_LOGIC_WIDTH - 1 : 0] snake_headx;
output  [V_LOGIC_WIDTH - 1 : 0] snake_heady;
output  [H_LOGIC_WIDTH - 1 : 0] snake_tailx;
output  [V_LOGIC_WIDTH - 1 : 0] snake_taily;
input   [H_LOGIC_WIDTH - 1 : 0] preyx;
input   [V_LOGIC_WIDTH - 1 : 0] preyy;


reg [SNAKE_DEPTH_MAX - 1 : 0] body;
reg [SNAKE_WIDTH     - 1 : 0] body_length;

reg [H_LOGIC_WIDTH - 1 : 0] headx;
reg [V_LOGIC_WIDTH - 1 : 0] heady;
reg [H_LOGIC_WIDTH - 1 : 0] tailx;
reg [V_LOGIC_WIDTH - 1 : 0] taily;

reg [H_LOGIC_WIDTH - 1 : 0] headx_next;
reg [V_LOGIC_WIDTH - 1 : 0] heady_next;

reg                          init;
wire                         init_done;
reg                  [1 : 0] ff_wren_init_cnt;
reg  [FF_DATA_WIDTH - 1 : 0] ff_wdat_init;


assign init_done = ff_wren_init_cnt == 2'b1;

always @(posedge clk) begin
    if (rst) begin
        init <= 1;
    end
    else if (init_done) begin
        init <= 0;
    end
end

always @(*) begin
    headx_next = headx;
    heady_next = heady;
    case (direction)
        DIR_UP  : heady_next = (heady == 0) ? V_LOGIC_MAX : heady - 1'b1;
        DIR_DOWN: heady_next = (heady == V_LOGIC_MAX) ? 0 : heady + 1'b1;
        DIR_LEFT: headx_next = (headx == 0) ? H_LOGIC_MAX : headx - 1'b1;
        DIR_RIGHT: headx_next = (headx == H_LOGIC_MAX) ? 0 : headx + 1'b1;
        default: begin
            headx_next = headx;
            heady_next = heady;
        end
    endcase
end

always @(posedge clk) begin
    if (rst | init) begin
        headx <= 'd16;
        heady <= 'd11;
    end
    else if (enb & valid) begin
        headx <= headx_next;
        heady <= heady_next;
    end
end

wire                         ff_full;
wire                         ff_empty;
wire                         ff_wren;
wire                         ff_rden;
wire                         ff_rvld;
wire [FF_DATA_WIDTH - 1 : 0] ff_wdat;
wire [FF_DATA_WIDTH - 1 : 0] ff_rdat;
wire [FF_DATA_WIDTH - 1 : 0] ff_check_dat;
wire                         ff_check_res;
wire                         ff_check_vld;
wire                         ff_wcheck_res;
wire                         ff_wcheck_vld;

wire                         score;
reg                          lose;

reg [1 : 0] valid_pp;
always @(posedge clk) begin
    valid_pp[0] <= valid;
    valid_pp[1] <= valid_pp[0];
end

always @(posedge clk) begin
    if (rst) begin
        ff_wren_init_cnt <= 0;
        ff_wdat_init     <= 0;
    end
    if (init) begin
        ff_wren_init_cnt <= ff_wren_init_cnt + 1'b1;
        ff_wdat_init     <= (ff_wren_init_cnt == 2'b0) ? {headx, heady} :
                            (ff_wren_init_cnt == 2'b1) ? {tailx, taily} : 0;
    end
end

assign ff_wren = (enb & valid_pp[0]) | init;
assign ff_wdat = (init) ? ff_wdat_init : {headx, heady};
assign ff_rden = enb & (~score) & valid_pp[0];

fifo_wcheck 
    #(
    .ADDR_WIDTH (SNAKE_WIDTH),
    .DATA_WIDTH (FF_DATA_WIDTH),
    .FIFO_DEPTH (SNAKE_DEPTH_MAX)
    )
snake_fifo (
    .clk            (clk),
    .rst            (rst),
    .wren           (ff_wren),
    .wdat           (ff_wdat),
    .rden           (ff_rden),
    .rdat           (ff_rdat),
    .rvld           (ff_rvld),
    .full           (ff_full),
    .empty          (ff_empty),
    .wcheck_res     (ff_wcheck_res),
    .wcheck_vld     (ff_wcheck_vld),
    .check_req      (ff_check_vld),
    .check_dat      (ff_check_dat),
    .check_res      (ff_check_res),
    .check_vld      (ff_check_vld),
);

always @(posedge clk) begin
    if (rst | init) begin
        tailx <= 'd15;
        taily <= 'd11;
    end
    else if (ff_rvld) begin
        {tailx, taily} <= ff_rdat;
    end
end

assign score = ({preyx, preyy} == {headx, heady}) & valid_pp[0];
assign snake_score = score;

always @(posedge clk) begin
    if (rst | init) begin
        lose <= 1'b0;
    end
    else if (ff_wcheck_res & ff_wcheck_vld) begin
        lose <= 1'b1;
    end
end
assign snake_lose = lose;

assign snake_headx = headx;
assign snake_heady = heady;
assign snake_tailx = tailx;
assign snake_taily = taily;

endmodule