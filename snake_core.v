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

parameter H_PHY_MAX         = 10'd639;
parameter V_PHY_MAX         = 9'd479;

localparam SPIXEL_PHY       = (H_PHY_MAX + 1) / (H_LOGIC_MAX + 1);

localparam SNAKE_H_MAX      = H_LOGIC_MAX;
localparam SNAKE_V_MAX      = V_LOGIC_MAX - 1'b1;

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

localparam VLD_1HZ_CNT_MAX = 25'd24999999;
localparam VLD_0_5HZ_CNT_MAX = 25'd12499999;
reg  [24:0] vld_cnt;
wire        vld;
wire        vld_start;
reg [3 : 0] vld_start_pp;

reg         init;
reg [2 : 0] init_pp;
wire        init_done;
wire        core_enb;

reg [CMD_WIDTH - 1 : 0] cmd_reg;
reg                     cmd_vld_reg;
reg             [1 : 0] cmd_cnt;
wire                    cmd_cnt_max_vld;
reg             [2 : 0] cmd_init_cnt;

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

always @(posedge clk) begin
    if (rst) begin
        init <= 1'b1;
    end
    else if (init_done) begin
        init <= 1'b0;
    end
    init_pp[0] <= init;
    init_pp[2:1] <= init_pp[1:0];
end

assign core_enb = enb & (~init);

reg [DIRECTION_WIDTH - 1 : 0] dir_detect_reg;
reg [DIRECTION_WIDTH - 1 : 0] dir_reg;

always @(posedge clk) begin
    if (rst) begin
        dir_detect_reg <= DIR_RIGHT;
    end
    else if (enb) begin
        casex ({up, down, left, right})
        4'b1xxx: dir_detect_reg <= (dir_reg == DIR_DOWN)  ? DIR_DOWN   : DIR_UP;
        4'b01xx: dir_detect_reg <= (dir_reg == DIR_UP)    ? DIR_UP     : DIR_DOWN;
        4'b001x: dir_detect_reg <= (dir_reg == DIR_RIGHT) ? DIR_RIGHT  : DIR_LEFT;
        4'b0001: dir_detect_reg <= (dir_reg == DIR_LEFT)  ? DIR_LEFT   : DIR_RIGHT;
        default: dir_detect_reg <= dir_detect_reg;
    endcase
    end
end

always @(posedge clk) begin
    if (rst) begin
        dir_reg <= DIR_RIGHT;
    end
    else if (vld) begin
        dir_reg <= dir_detect_reg;
    end
end

wire                         snake_score;
wire                         snake_lose;
wire [H_LOGIC_WIDTH - 1 : 0] snake_headx;
wire [V_LOGIC_WIDTH - 1 : 0] snake_heady;
wire [H_LOGIC_WIDTH - 1 : 0] snake_tailx;
wire [V_LOGIC_WIDTH - 1 : 0] snake_taily;
wire [H_LOGIC_WIDTH - 1 : 0] preyx;
wire [V_LOGIC_WIDTH - 1 : 0] preyy;
wire                         prey_vld;

reg user_score;

always @(posedge clk) begin
    if (rst) begin
        user_score <= 0;
    end
    else if (snake_score) begin
        user_score <= user_score + 1'b1;
    end
end

snake_body
    #(
    .SNAKE_DEPTH_MAX   (SNAKE_DEPTH_MAX),
    .SNAKE_WIDTH       (SNAKE_WIDTH),
    .H_LOGIC_WIDTH     (H_LOGIC_WIDTH),
    .V_LOGIC_WIDTH     (V_LOGIC_WIDTH),
    .H_LOGIC_MAX       (SNAKE_H_MAX),
    .V_LOGIC_MAX       (SNAKE_V_MAX)
    )
i_snake_body (
    .clk                (clk),
    .rst                (rst),
    .enb                (core_enb),
    .direction          (dir_reg),
    .valid              (vld_start),
    .snake_score        (snake_score),
    .snake_lose         (snake_lose),
    .snake_headx        (snake_headx),
    .snake_heady        (snake_heady),
    .snake_tailx        (snake_tailx),
    .snake_taily        (snake_taily),
    .preyx              (preyx),
    .preyy              (preyy)
    );

snake_prey
    #(
    .H_LOGIC_WIDTH     (H_LOGIC_WIDTH),
    .V_LOGIC_WIDTH     (V_LOGIC_WIDTH),
    .H_LOGIC_MAX       (SNAKE_H_MAX),
    .V_LOGIC_MAX       (SNAKE_V_MAX)
    )
i_snake_prey(
    .clk                (clk),
    .rst                (rst),
    .enb                (core_enb),
    .valid              (snake_score),
    .preyx              (preyx),
    .preyy              (preyy),
    .prey_vld           (prey_vld)
);

// Draw Command generate
localparam CMD_CLEAR_SCREEN  = {4'h1, 5'b0, 5'b0, H_LOGIC_MAX, V_LOGIC_MAX, 8'hff};
localparam CMD_BORDER_LINE_0 = {4'h9, 10'b0, 9'd460, 8'h02, 1'b0};
localparam CMD_BORDER_LINE_1 = {4'h9, H_PHY_MAX, 9'd462, 8'h02, 1'b1};

assign cmd_cnt_max_vld = cmd_cnt == 2'b10;
assign init_done = cmd_init_cnt == 3'b011;

always @(posedge clk) begin
    if (rst | vld_start | snake_lose) begin
        cmd_reg <= 0;
        cmd_cnt <= 0;
        cmd_init_cnt <= 0;
        cmd_vld_reg <= 0;
    end
    else if (init) begin
        cmd_init_cnt <= cmd_init_cnt + 1'b1;
        cmd_vld_reg <= 1'b1;

        case (cmd_init_cnt)
            3'b000: cmd_reg <= CMD_CLEAR_SCREEN;
            3'b001: cmd_reg <= CMD_BORDER_LINE_0;
            3'b010: cmd_reg <= CMD_BORDER_LINE_1;
            3'b011: cmd_reg <= {4'h0, preyx, preyy, 8'h3c, 10'b0};
            default: cmd_reg <= cmd_reg;
        endcase
    end
    else if (prey_vld) begin
        cmd_reg <= {4'h0, preyx, preyy, 8'h3c, 10'b0};
        cmd_vld_reg <= 1'b1;
    end
    else if (~cmd_cnt_max_vld) begin
        cmd_cnt <= cmd_cnt + 1'b1;
        cmd_vld_reg <= 1'b1;
        if (cmd_cnt == 2'b0) begin
            cmd_reg <= {4'h0, snake_headx, snake_heady, 8'h0f, 10'b0};
        end
        else if (cmd_cnt == 2'b1) begin
            cmd_reg <= {4'h0, snake_tailx, snake_taily, 8'hff, 10'b0};
        end
    end
    else begin
        cmd_vld_reg <= 1'b0;
    end
end

assign cmd = cmd_reg;
assign cmd_vld = cmd_vld_reg;

endmodule