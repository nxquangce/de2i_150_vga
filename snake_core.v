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
parameter SCORE_WIDTH       = 10;

parameter H_PHY_MAX         = 10'd639;
parameter V_PHY_MAX         = 9'd479;

localparam SPIXEL_PHY       = (H_PHY_MAX + 1) / (H_LOGIC_MAX + 1);

localparam SNAKE_H_MAX      = H_LOGIC_MAX;
localparam SNAKE_V_MAX      = V_LOGIC_MAX - 2'd2;

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
localparam VLD_0_875HZ_CNT_MAX = 25'd21874999;
localparam VLD_0_75HZ_CNT_MAX = 25'd18749999;
localparam VLD_0_625HZ_CNT_MAX = 25'd15624999;
localparam VLD_0_5HZ_CNT_MAX = 25'd12499999;
localparam VLD_0_375HZ_CNT_MAX = 25'd9374999;
localparam VLD_0_25HZ_CNT_MAX = 25'd6249999;
localparam VLD_0_1875HZ_CNT_MAX = 25'd4687499;
localparam VLD_0_125HZ_CNT_MAX = 25'd3124999;
localparam VLD_0_0625HZ_CNT_MAX = 25'd1562499;
localparam VLD_0_03125HZ_CNT_MAX = 25'd781249;

reg            [24 : 0] vld_cnt;
reg            [24 : 0] vld_cnt_max;
wire                    vld;
wire                    vld_start;
reg             [3 : 0] vld_start_pp;

reg                     init;
reg             [2 : 0] init_pp;
wire                    init_done;
wire                    core_enb;

reg [CMD_WIDTH - 1 : 0] cmd_reg;
reg                     cmd_vld_reg;
reg             [3 : 0] cmd_cnt;
wire                    cmd_cnt_max_vld;
reg             [7 : 0] cmd_init_cnt;
wire            [2 : 0] settings;
reg             [2 : 0] settings_reg;
wire            [2 : 0] settings_level;

assign settings_level = settings_reg[2:0];

always @(posedge clk) begin
    vld_cnt_max <= (settings_level == 3'd0) ? VLD_1HZ_CNT_MAX : 
                   (settings_level == 3'd1) ? VLD_0_75HZ_CNT_MAX :
                   (settings_level == 3'd2) ? VLD_0_5HZ_CNT_MAX :
                   (settings_level == 3'd3) ? VLD_0_25HZ_CNT_MAX :
                   (settings_level == 3'd4) ? VLD_0_1875HZ_CNT_MAX :
                   (settings_level == 3'd5) ? VLD_0_125HZ_CNT_MAX :
                   (settings_level == 3'd6) ? VLD_0_0625HZ_CNT_MAX : VLD_0_03125HZ_CNT_MAX;
end

assign vld = (vld_cnt == vld_cnt_max);
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
wire                         prey_res;
wire                         prey_res_vld;
wire                         prey_bad;
wire                         prey_good;
wire                         prey_gen_vld;
reg                          prey_good_cache;
reg                          prey_good_clear;

reg [SCORE_WIDTH - 1 : 0] user_score;
wire      [4 * 4 - 1 : 0] user_score_bcd;
wire              [7 : 0] user_score_char [3 : 0];

always @(posedge clk) begin
    if (rst) begin
        user_score <= 0;
    end
    else if (snake_score) begin
        user_score <= user_score + settings_level + 1'b1;
    end
end

bin2bcd 
    #(
    .BIT_WIDTH  (SCORE_WIDTH),
    .NUM_BCD    (4)
    )
user_score_bin2bcd(user_score, user_score_bcd);

bcd2ascii score_char0(user_score_bcd[3:0], user_score_char[0]);
bcd2ascii score_char1(user_score_bcd[7:4], user_score_char[1]);
bcd2ascii score_char2(user_score_bcd[11:8], user_score_char[2]);
bcd2ascii score_char3(user_score_bcd[15:12], user_score_char[3]);

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
    .preyy              (preyy),
    .prey_vld           (prey_vld),
    .prey_res           (prey_res),
    .prey_res_vld       (prey_res_vld)
    );

assign prey_bad  =   prey_res  & prey_res_vld;
assign prey_good = (~prey_res) & prey_res_vld;
assign prey_gen_vld = snake_score | prey_bad;

always @(posedge clk) begin
    if (rst | prey_good_clear) begin
        prey_good_cache <= 1'b0;
    end
    else if (prey_good) begin
        prey_good_cache <= 1'b1;
    end
end

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
    .valid              (prey_gen_vld),
    .preyx              (preyx),
    .preyy              (preyy),
    .prey_vld           (prey_vld)
);

// Draw Command generate
localparam SCOREX_POSY       = 9'd450;
localparam SCORE0_POSX       = 10'd619;
localparam SCORE1_POSX       = SCORE0_POSX - 10'd20;
localparam SCORE2_POSX       = SCORE1_POSX - 10'd20;
localparam SCORE3_POSX       = SCORE2_POSX - 10'd20;
localparam SCOREX_COLOR_FG   = 8'h00;
localparam SCOREX_COLOR_BG   = 8'hff;
localparam SCOREX_SIZE       = 4'h1;
localparam CMD_CLEAR_SCREEN  = {4'h1, 5'b0, 5'b0, H_LOGIC_MAX, V_LOGIC_MAX, 8'hff};
localparam CMD_BORDER_LINE_0 = {4'h9, 10'b0, 9'd440, 8'h02, 1'b0};
localparam CMD_BORDER_LINE_1 = {4'h9, H_PHY_MAX, 9'd442, 8'h02, 1'b1};
localparam CMD_POINT_ZERO0_0 = {4'ha, SCORE0_POSX, SCOREX_POSY, 8'h30, 1'b0};
localparam CMD_POINT_ZERO0_1 = {4'ha, SCOREX_COLOR_FG, SCOREX_COLOR_BG, SCOREX_SIZE, 8'h1};
localparam CMD_POINT_ZERO1_0 = {4'ha, SCORE1_POSX, SCOREX_POSY, 8'h30, 1'b0};
localparam CMD_POINT_ZERO1_1 = {4'ha, SCOREX_COLOR_FG, SCOREX_COLOR_BG, SCOREX_SIZE, 8'h1};
localparam CMD_POINT_ZERO2_0 = {4'ha, SCORE2_POSX, SCOREX_POSY, 8'h30, 1'b0};
localparam CMD_POINT_ZERO2_1 = {4'ha, SCOREX_COLOR_FG, SCOREX_COLOR_BG, SCOREX_SIZE, 8'h1};
localparam CMD_POINT_ZERO3_0 = {4'ha, SCORE3_POSX, SCOREX_POSY, 8'h30, 1'b0};
localparam CMD_POINT_ZERO3_1 = {4'ha, SCOREX_COLOR_FG, SCOREX_COLOR_BG, SCOREX_SIZE, 8'h1};

localparam SETTING_MODE_POSX = 10'd20;
localparam SETTING_MODE_POSY = SCOREX_POSY;
localparam SETTING_LEVEL_POSX = 10'd150;
localparam SETTING_LEVEL_POSY = SCOREX_POSY;

wire [CMD_WIDTH - 1 : 0] cmd_startscren;
wire                     cmd_startscren_vld;
wire                     start_game_vld;
reg                      startscreen_enb;

always @(posedge clk) begin
    if (rst) begin
        startscreen_enb <= 1;
        settings_reg <= 3'd1;
    end
    else if (start_game_vld) begin
        startscreen_enb <= 0;
        settings_reg <= settings;
    end
end

snake_startscreen i_snake_startscreen(
    .clk        (clk),
    .rst        (rst),
    .up         (up),
    .down       (down),
    .left       (left),
    .right      (right),
    .start      (start_game_vld),
    .settings   (settings),
    .enb        (startscreen_enb & enb),
    .cmd        (cmd_startscren),
    .cmd_vld    (cmd_startscren_vld)
);

assign cmd_cnt_max_vld = cmd_cnt == 4'ha;
assign init_done = cmd_init_cnt == 8'h45;

always @(posedge clk) begin
    if (rst | vld_start | snake_lose) begin
        cmd_reg <= 0;
        cmd_cnt <= 0;
        cmd_init_cnt <= 0;
        cmd_vld_reg <= 0;
        prey_good_clear <= 0;
    end
    else if (startscreen_enb) begin
        cmd_reg <= cmd_startscren;
        cmd_vld_reg <= cmd_startscren_vld;
    end
    else if (init & enb) begin
        cmd_init_cnt <= cmd_init_cnt + 1'b1;
        cmd_vld_reg <= 1'b1;

        case (cmd_init_cnt)
            8'h00: cmd_reg <= CMD_CLEAR_SCREEN;
            8'h01: cmd_reg <= CMD_BORDER_LINE_0;
            8'h02: cmd_reg <= CMD_BORDER_LINE_1;
            8'h03: cmd_reg <= {4'h0, preyx, preyy, 8'h3c, 10'b0};
            8'h04: cmd_reg <= CMD_POINT_ZERO0_0;
            8'h05: cmd_reg <= CMD_POINT_ZERO0_1;
            8'h06: cmd_reg <= CMD_POINT_ZERO1_0;
            8'h07: cmd_reg <= CMD_POINT_ZERO1_1;
            8'h08: cmd_reg <= CMD_POINT_ZERO2_0;
            8'h09: cmd_reg <= CMD_POINT_ZERO2_1;
            8'h0a: cmd_reg <= CMD_POINT_ZERO3_0;
            8'h0b: cmd_reg <= CMD_POINT_ZERO3_1;

            8'h0c: cmd_reg <= {4'ha, SETTING_MODE_POSX, SETTING_MODE_POSY, 8'h43, 1'b0};
            8'h0d: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};
            8'h0e: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd12, SETTING_MODE_POSY, 8'h6c, 1'b0};
            8'h0f: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};
            8'h10: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd24, SETTING_MODE_POSY, 8'h61, 1'b0};
            8'h21: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};
            8'h22: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd36, SETTING_MODE_POSY, 8'h73, 1'b0};
            8'h23: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};
            8'h24: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd48, SETTING_MODE_POSY, 8'h73, 1'b0};
            8'h25: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};
            8'h26: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd60, SETTING_MODE_POSY, 8'h69, 1'b0};
            8'h27: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};
            8'h28: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd72, SETTING_MODE_POSY, 8'h63, 1'b0};
            8'h29: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};

            8'h3a: cmd_reg <= {4'ha, SETTING_LEVEL_POSX, SETTING_LEVEL_POSY, 8'h4c, 1'b0};
            8'h3b: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};
            8'h3c: cmd_reg <= {4'ha, SETTING_LEVEL_POSX + 10'd12, SETTING_LEVEL_POSY, 8'h65, 1'b0};
            8'h3d: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};
            8'h3e: cmd_reg <= {4'ha, SETTING_LEVEL_POSX + 10'd24, SETTING_LEVEL_POSY, 8'h76, 1'b0};
            8'h3f: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};
            8'h40: cmd_reg <= {4'ha, SETTING_LEVEL_POSX + 10'd36, SETTING_LEVEL_POSY, 8'h65, 1'b0};
            8'h41: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};
            8'h42: cmd_reg <= {4'ha, SETTING_LEVEL_POSX + 10'd48, SETTING_LEVEL_POSY, 8'h6c, 1'b0};
            8'h43: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};
            8'h44: cmd_reg <= {4'ha, SETTING_LEVEL_POSX + 10'd72, SETTING_LEVEL_POSY, 8'h31 + settings_level, 1'b0};
            8'h45: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h1, 8'h1};
            default: cmd_reg <= cmd_reg;
        endcase
    end
    else if (~cmd_cnt_max_vld & enb) begin
        cmd_cnt <= cmd_cnt + 1'b1;
        cmd_vld_reg <= 1'b1;

        case (cmd_cnt)
            4'h0: cmd_reg <= {4'h0, snake_headx, snake_heady, 8'h0f, 10'b0};
            4'h1: cmd_reg <= {4'h0, snake_tailx, snake_taily, 8'hff, 10'b0};
            4'h2: cmd_reg <= {4'ha, SCORE0_POSX, SCOREX_POSY, user_score_char[0], 1'b0};
            4'h3: cmd_reg <= {4'ha, SCOREX_COLOR_FG, SCOREX_COLOR_BG, SCOREX_SIZE, 8'h1};
            4'h4: cmd_reg <= {4'ha, SCORE1_POSX, SCOREX_POSY, user_score_char[1], 1'b0};
            4'h5: cmd_reg <= {4'ha, SCOREX_COLOR_FG, SCOREX_COLOR_BG, SCOREX_SIZE, 8'h1};
            4'h6: cmd_reg <= {4'ha, SCORE2_POSX, SCOREX_POSY, user_score_char[2], 1'b0};
            4'h7: cmd_reg <= {4'ha, SCOREX_COLOR_FG, SCOREX_COLOR_BG, SCOREX_SIZE, 8'h1};
            4'h8: cmd_reg <= {4'ha, SCORE3_POSX, SCOREX_POSY, user_score_char[3], 1'b0};
            4'h9: cmd_reg <= {4'ha, SCOREX_COLOR_FG, SCOREX_COLOR_BG, SCOREX_SIZE, 8'h1};
            default: begin
                cmd_reg <= cmd_reg;
            end
        endcase
    end
    else if (prey_good_cache & enb) begin
        prey_good_clear <= 1'b1;
        cmd_reg <= {4'h0, preyx, preyy, 8'h3c, 10'b0};
        cmd_vld_reg <= 1'b1;
    end
    else begin
        cmd_vld_reg <= 1'b0;
        prey_good_clear <= 1'b0;
    end
end

assign cmd = cmd_reg;
assign cmd_vld = cmd_vld_reg;

endmodule