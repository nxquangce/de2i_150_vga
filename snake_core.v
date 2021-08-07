module snake_core(
    clk,
    rst,
    enb,
    up,
    down,
    left,
    right,
    cmd,
    cmd_vld
);

parameter SNAKE_DEPTH_MAX   = 128;
parameter SNAKE_WIDTH       = 7;
parameter H_LOGIC_WIDTH     = 5;
parameter V_LOGIC_WIDTH     = 5;
parameter H_LOGIC_MAX       = 5'd31;
parameter V_LOGIC_MAX       = 5'd23;
parameter COLOR_ID_WIDTH    = 8;

localparam CMD_WIDTH        = 4 + (H_LOGIC_WIDTH + V_LOGIC_WIDTH) * 2 + COLOR_ID_WIDTH; // = 32
localparam DIRECTION_WIDTH  = 2;
localparam DIR_UP           = 2'b00;
localparam DIR_DOWN         = 2'b11;
localparam DIR_LEFT         = 2'b10;
localparam DIR_RIGHT        = 2'b01;

input                      clk;
input                      rst;
input                      enb;
input                      up;
input                      down;
input                      left;
input                      right;
output [CMD_WIDTH - 1 : 0] cmd;
output                     cmd_vld;

reg [DIRECTION_WIDTH - 1 : 0] dir_reg;
always @(posedge clk) begin
    if (rst) begin
        dir_reg <= DIR_RIGHT;
    end
    else if (enb) begin
        casex ({up, down, left, right})
        4'b1xxx: dir_reg = DIR_UP;
        4'b01xx: dir_reg = DIR_DOWN;
        4'b001x: dir_reg = DIR_LEFT;
        4'b0001: dir_reg = DIR_RIGHT;
        default: dir_reg = dir_reg;
    endcase
    end
end

localparam VLD_1HZ_CNT_MAX = 25'd24999999;
localparam VLD_0_5HZ_CNT_MAX = 25'd12499999;
reg  [24:0] vld_cnt;
wire        vld;
wire        vld_start;
reg [3 : 0] vld_start_pp;

// Update interval time = 0.25s
assign vld = (vld_cnt == VLD_0_5HZ_CNT_MAX);
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

reg init;
wire init_done;

assign init_done = vld;

always @(posedge clk) begin
    if (rst) begin
        init <= 1'b1;
    end
    else if (init_done) begin
        init <= 1'b0;
    end
end

wire [H_LOGIC_WIDTH - 1 : 0] snake_headx;
wire [V_LOGIC_WIDTH - 1 : 0] snake_heady;
wire [H_LOGIC_WIDTH - 1 : 0] snake_tailx;
wire [V_LOGIC_WIDTH - 1 : 0] snake_taily;
wire [H_LOGIC_WIDTH - 1 : 0] preyx;
wire [V_LOGIC_WIDTH - 1 : 0] preyy;


snake_body
    #(
    .SNAKE_DEPTH_MAX   (SNAKE_DEPTH_MAX),
    .SNAKE_WIDTH       (SNAKE_WIDTH),
    .H_LOGIC_WIDTH     (H_LOGIC_WIDTH),
    .V_LOGIC_WIDTH     (V_LOGIC_WIDTH),
    .H_LOGIC_MAX       (H_LOGIC_MAX),
    .V_LOGIC_MAX       (V_LOGIC_MAX)
    )
i_snake_body (
    .clk                (clk),
    .rst                (rst),
    .enb                (enb),
    .direction          (dir_reg),
    .valid              (vld_start),
    .score              (1'b0),
    .snake_headx        (snake_headx),
    .snake_heady        (snake_heady),
    .snake_tailx        (snake_tailx),
    .snake_taily        (snake_taily)
    );

snake_prey i_snake_prey(
    .clk                (clk),
    .rst                (rst),
    .enb                (enb),
    .valid              (vld_start),
    .preyx              (preyx),
    .preyy              (preyy)
);

reg [CMD_WIDTH - 1 : 0] cmd_reg;
reg                     cmd_vld_reg;
reg             [1 : 0] cmd_cnt;
wire                    cmd_cnt_max_vld;

assign cmd_cnt_max_vld = cmd_cnt == 2'b11;

always @(posedge clk) begin
    if (rst | vld_start) begin
        cmd_reg <= 0;
        cmd_cnt <= 0;
        cmd_vld_reg <= 0;
    end
    if (init) begin
        cmd_reg <= {4'h1, 5'b0, 5'b0, H_LOGIC_MAX, V_LOGIC_MAX, 8'hff};
        cmd_vld_reg <= 1'b1;
    end
    else if (~cmd_cnt_max_vld) begin
        cmd_cnt <= cmd_cnt + 1'b1;
        cmd_vld_reg <= 1'b1;
        if (cmd_cnt == 0) begin
            cmd_reg <= {4'h0, snake_headx, snake_heady, 8'h0f, 10'b0};
        end
        else if (cmd_cnt == 1) begin
            cmd_reg <= {4'h0, snake_tailx, snake_taily, 8'hff, 10'b0};
        end
        else begin
            cmd_reg <= {4'h0, preyx, preyy, 8'he0, 10'b0};
        end
    end
    else begin
        cmd_vld_reg <= 1'b0;
    end
end

assign cmd = cmd_reg;
assign cmd_vld = cmd_vld_reg;

endmodule