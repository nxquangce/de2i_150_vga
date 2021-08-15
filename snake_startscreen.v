module snake_startscreen (
    clk,
    rst,
    enb,
    up,
    down,
    left,
    right,
    start,
    cmd,
    cmd_vld
);
parameter H_LOGIC_WIDTH     = 5;
parameter V_LOGIC_WIDTH     = 5;
parameter H_LOGIC_MAX       = 5'd31;
parameter V_LOGIC_MAX       = 5'd23;
parameter COLOR_ID_WIDTH    = 8;

parameter H_PHY_MAX         = 10'd639;
parameter V_PHY_MAX         = 9'd479;

localparam SPIXEL_PHY       = (H_PHY_MAX + 1) / (H_LOGIC_MAX + 1);

localparam SNAKE_H_MAX      = H_LOGIC_MAX;
localparam SNAKE_V_MAX      = V_LOGIC_MAX - 2'd2;

localparam CMD_WIDTH        = 4 + (H_LOGIC_WIDTH + V_LOGIC_WIDTH) * 2 + COLOR_ID_WIDTH; // = 32

input                      clk;
input                      rst;
input                      enb;
input                      up;
input                      down;
input                      left;
input                      right;
output                     start;
output [CMD_WIDTH - 1 : 0] cmd;
output                     cmd_vld;

localparam CMD_CLEAR_SCREEN  = {4'h1, 5'b0, 5'b0, H_LOGIC_MAX, V_LOGIC_MAX, 8'hff};

reg             [6 : 0] cmd_cnt;
reg [CMD_WIDTH - 1 : 0] cmd_reg;
reg                     cmd_vld_reg;
wire                    cmd_cnt_max_vld;

reg                     ops_id;
wire                    cmd_nav_cnt_max_vld;
wire [COLOR_ID_WIDTH - 1 : 0] ops_color [1 : 0];

wire                    setting_vld;
wire                    setting_end;
reg                     setting_enb;
reg             [1 : 0] setting_id;
wire                    cmd_setting_cnt_max_vld;
wire [COLOR_ID_WIDTH - 1 : 0] setting_color [3 : 0];

reg             [2 : 0] level_reg;

reg                     init;
reg             [2 : 0] state;
reg             [2 : 0] state_next;

localparam S_ILDE = 2'b0, S_INIT = 2'b01, S_STARTNAV = 2'b10, S_SETTING = 2'b11;

always @(posedge clk) begin
    if (rst) begin
        init <= 1;
    end
    else if (state == S_INIT) begin
        init <= 0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        state <= S_ILDE;
    end
    else if (enb) begin
        state <= state_next;
    end
end

always @(*) begin
    case (state)
        S_ILDE: begin
            if (init) state_next = S_INIT;
            else if ((~setting_enb) & (up | down)) state_next = S_STARTNAV;
            else if (setting_end) state_next = S_INIT;
            else if (setting_enb & (up | down | right)) state_next = S_SETTING;
            else if (setting_vld) state_next = S_SETTING;
            else state_next = S_ILDE;
        end
        S_INIT: 
            state_next = (cmd_cnt_max_vld) ? S_ILDE : S_INIT;
        S_STARTNAV:
            state_next = (cmd_nav_cnt_max_vld) ? S_ILDE : S_STARTNAV;
        S_SETTING:
            state_next = (cmd_setting_cnt_max_vld) ? S_ILDE : S_SETTING;
        default: begin
            state_next = state;
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        ops_id <= 0;
    end
    else if (up) begin
        ops_id <= ops_id + 1'b1;
    end
    else if (down) begin
        ops_id <= ops_id - 1'b1;
    end
end

assign ops_color[0] = (ops_id == 0) ? 8'h3c : 8'hff;
assign ops_color[1] = (ops_id == 1) ? 8'h3c : 8'hff;

assign setting_vld = (ops_id == 1'b1) & right;
assign setting_end = setting_enb & (setting_id == 2'd3) & right;

always @(posedge clk) begin
    if (rst | setting_end) begin
        setting_enb <= 1'b0;
    end 
    else if (setting_vld) begin
        setting_enb <= 1'b1;
    end
end

always @(posedge clk) begin
    if (rst | setting_end) begin
        setting_id <= 0;
    end
    else if (setting_enb) begin
        if (up) begin
            setting_id <= setting_id + 1'b1;
        end
        else if (down) begin
            setting_id <= setting_id - 1'b1;
        end
    end
end

assign setting_color[0] = (setting_id == 2'd0) ? 8'h03 : 8'h00;
assign setting_color[1] = (setting_id == 2'd1) ? 8'h03 : 8'h00;
assign setting_color[2] = (setting_id == 2'd2) ? 8'h03 : 8'h00;
assign setting_color[3] = (setting_id == 2'd3) ? 8'h03 : 8'h00;

wire level_vld;

assign level_vld = setting_enb & (setting_id == 2'd1) & right;

always @(posedge clk) begin
    if (rst) begin
        level_reg <= 3'd1;
    end
    else if (level_vld) begin
        level_reg <= level_reg  + 1'b1;
    end
end

localparam INS_POSX = 10'd560;
localparam INS_POSY = 9'd400;
localparam SETTING_TITLE_POSX = 10'd20;
localparam SETTING_TITLE_POSY = 9'd20;
localparam SETTING_MODE_POSX = SETTING_TITLE_POSX + 10'd28;
localparam SETTING_MODE_POSY = SETTING_TITLE_POSY + 9'd40;
localparam SETTING_LEVEL_POSX = SETTING_MODE_POSX;
localparam SETTING_LEVEL_POSY = SETTING_MODE_POSY + 9'd40;
localparam SETTING_MAP_POSX = SETTING_LEVEL_POSX;
localparam SETTING_MAP_POSY = SETTING_LEVEL_POSY + 9'd40;
localparam SETTING_OK_POSX = SETTING_MAP_POSY + 10'd54;
localparam SETTING_OK_POSY = SETTING_MAP_POSY + 9'd60;

localparam SETTING_TITLE_COLOR = 8'h3c;

assign cmd_cnt_max_vld = cmd_cnt == 7'h4c;
assign cmd_nav_cnt_max_vld = cmd_cnt == 7'd3;
assign cmd_setting_cnt_max_vld = cmd_cnt == 7'h4a;

always @(posedge clk) begin
    if (rst) begin
        cmd_cnt <= 0;
        cmd_reg <= 0;
        cmd_vld_reg <= 0;
    end
    else if (enb) begin
        case (state)
            S_INIT: begin
                cmd_cnt <= cmd_cnt + 1'b1;
                cmd_vld_reg <= 1;

                case (cmd_cnt)
                    7'h00: cmd_reg <= CMD_CLEAR_SCREEN;
                    7'h01: cmd_reg <= {4'ha, 10'd70, 9'd120, 8'h53, 1'b0};
                    7'h02: cmd_reg <= {4'ha, 8'he0, 8'hff, 4'hf, 8'h1};
                    7'h03: cmd_reg <= {4'ha, 10'd170, 9'd120, 8'h4e, 1'b0};
                    7'h04: cmd_reg <= {4'ha, 8'he0, 8'hff, 4'hf, 8'h1};
                    7'h05: cmd_reg <= {4'ha, 10'd270, 9'd120, 8'h41, 1'b0};
                    7'h06: cmd_reg <= {4'ha, 8'he0, 8'hff, 4'hf, 8'h1};
                    7'h07: cmd_reg <= {4'ha, 10'd370, 9'd120, 8'h4b, 1'b0};
                    7'h08: cmd_reg <= {4'ha, 8'he0, 8'hff, 4'hf, 8'h1};
                    7'h09: cmd_reg <= {4'ha, 10'd470, 9'd120, 8'h45, 1'b0};
                    7'h0a: cmd_reg <= {4'ha, 8'he0, 8'hff, 4'hf, 8'h1};

                    7'h0b: cmd_reg <= {4'ha, INS_POSX, INS_POSY, 8'h4b, 1'b0};
                    7'h0c: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h0d: cmd_reg <= {4'ha, INS_POSX + 10'd6, INS_POSY, 8'h45, 1'b0};
                    7'h0e: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h0f: cmd_reg <= {4'ha, INS_POSX + 10'd12, INS_POSY, 8'h59, 1'b0};
                    7'h10: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h11: cmd_reg <= {4'ha, INS_POSX + 10'd21, INS_POSY, 8'h32, 1'b0};
                    7'h12: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h13: cmd_reg <= {4'ha, INS_POSX + 10'd27, INS_POSY, 8'h3a, 1'b0};
                    7'h14: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h15: cmd_reg <= {4'ha, INS_POSX + 10'd33, INS_POSY, 8'h80, 1'b0};
                    7'h16: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};

                    7'h17: cmd_reg <= {4'ha, INS_POSX, INS_POSY + 9'd15, 8'h4b, 1'b0};
                    7'h18: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h19: cmd_reg <= {4'ha, INS_POSX + 10'd6, INS_POSY + 9'd15, 8'h45, 1'b0};
                    7'h1a: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h1b: cmd_reg <= {4'ha, INS_POSX + 10'd12, INS_POSY + 9'd15, 8'h59, 1'b0};
                    7'h1c: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h1d: cmd_reg <= {4'ha, INS_POSX + 10'd21, INS_POSY + 9'd15, 8'h31, 1'b0};
                    7'h1e: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h1f: cmd_reg <= {4'ha, INS_POSX + 10'd27, INS_POSY + 9'd15, 8'h3a, 1'b0};
                    7'h20: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h21: cmd_reg <= {4'ha, INS_POSX + 10'd33, INS_POSY + 9'd15, 8'h81, 1'b0};
                    7'h22: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};

                    7'h23: cmd_reg <= {4'ha, INS_POSX, INS_POSY + 9'd30, 8'h4b, 1'b0};
                    7'h24: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h25: cmd_reg <= {4'ha, INS_POSX + 10'd6, INS_POSY + 9'd30, 8'h45, 1'b0};
                    7'h26: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h27: cmd_reg <= {4'ha, INS_POSX + 10'd12, INS_POSY + 9'd30, 8'h59, 1'b0};
                    7'h28: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h29: cmd_reg <= {4'ha, INS_POSX + 10'd21, INS_POSY + 9'd30, 8'h30, 1'b0};
                    7'h2a: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h2b: cmd_reg <= {4'ha, INS_POSX + 10'd27, INS_POSY + 9'd30, 8'h3a, 1'b0};
                    7'h2c: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h2d: cmd_reg <= {4'ha, INS_POSX + 10'd33, INS_POSY + 9'd30, 8'h4f, 1'b0};
                    7'h2e: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};
                    7'h2f: cmd_reg <= {4'ha, INS_POSX + 10'd39, INS_POSY + 9'd30, 8'h4b, 1'b0};
                    7'h30: cmd_reg <= {4'ha, 8'h00, 8'hff, 4'h0, 8'h1};

                    7'h31: cmd_reg <= {4'ha, 10'd290, 9'd340, 8'h53, 1'b0};
                    7'h32: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};
                    7'h33: cmd_reg <= {4'ha, 10'd302, 9'd340, 8'h54, 1'b0};
                    7'h34: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};
                    7'h35: cmd_reg <= {4'ha, 10'd314, 9'd340, 8'h41, 1'b0};
                    7'h36: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};
                    7'h37: cmd_reg <= {4'ha, 10'd326, 9'd340, 8'h52, 1'b0};
                    7'h38: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};
                    7'h39: cmd_reg <= {4'ha, 10'd338, 9'd340, 8'h54, 1'b0};
                    7'h3a: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};

                    7'h3b: cmd_reg <= {4'ha, 10'd272, 9'd365, 8'h53, 1'b0};
                    7'h3c: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};
                    7'h3d: cmd_reg <= {4'ha, 10'd284, 9'd365, 8'h45, 1'b0};
                    7'h3e: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};
                    7'h3f: cmd_reg <= {4'ha, 10'd296, 9'd365, 8'h54, 1'b0};
                    7'h40: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};
                    7'h41: cmd_reg <= {4'ha, 10'd308, 9'd365, 8'h54, 1'b0};
                    7'h42: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};
                    7'h43: cmd_reg <= {4'ha, 10'd320, 9'd365, 8'h49, 1'b0};
                    7'h44: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};
                    7'h45: cmd_reg <= {4'ha, 10'd332, 9'd365, 8'h4e, 1'b0};
                    7'h46: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};
                    7'h47: cmd_reg <= {4'ha, 10'd344, 9'd365, 8'h47, 1'b0};
                    7'h48: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};
                    7'h49: cmd_reg <= {4'ha, 10'd356, 9'd365, 8'h53, 1'b0};
                    7'h4a: cmd_reg <= {4'ha, 8'h03, 8'hff, 4'h1, 8'h1};

                    7'h4b: cmd_reg <= {4'h9, 10'd290, 9'd362, 8'h3c, 1'b0};
                    7'h4c: cmd_reg <= {4'h9, 10'd350, 9'd362, 8'h3c, 1'b1};

                    default: cmd_reg <= cmd_reg;
                endcase
            end
            S_STARTNAV: begin
                cmd_cnt <= cmd_cnt + 1'b1;
                cmd_vld_reg <= 1;

                case (cmd_cnt)
                    7'h0: cmd_reg <= {4'h9, 10'd290, 9'd362, ops_color[0], 1'b0};
                    7'h1: cmd_reg <= {4'h9, 10'd350, 9'd362, ops_color[0], 1'b1};
                    7'h2: cmd_reg <= {4'h9, 10'd272, 9'd387, ops_color[1], 1'b0};
                    7'h3: cmd_reg <= {4'h9, 10'd368, 9'd387, ops_color[1], 1'b1};
                    default: cmd_reg <= cmd_reg;
                endcase
            end
            S_SETTING: begin
                cmd_cnt <= cmd_cnt + 1'b1;
                cmd_vld_reg <= 1;

                case (cmd_cnt)
                    7'h00: cmd_reg <= CMD_CLEAR_SCREEN;
                    7'h01: cmd_reg <= {4'ha, SETTING_TITLE_POSX, SETTING_TITLE_POSY, 8'h53, 1'b0};
                    7'h02: cmd_reg <= {4'ha, SETTING_TITLE_COLOR, 8'hff, 4'h1, 8'h1};
                    7'h03: cmd_reg <= {4'ha, SETTING_TITLE_POSX + 10'd12, SETTING_TITLE_POSY, 8'h45, 1'b0};
                    7'h04: cmd_reg <= {4'ha, SETTING_TITLE_COLOR, 8'hff, 4'h1, 8'h1};
                    7'h05: cmd_reg <= {4'ha, SETTING_TITLE_POSX + 10'd24, SETTING_TITLE_POSY, 8'h54, 1'b0};
                    7'h06: cmd_reg <= {4'ha, SETTING_TITLE_COLOR, 8'hff, 4'h1, 8'h1};
                    7'h07: cmd_reg <= {4'ha, SETTING_TITLE_POSX + 10'd36, SETTING_TITLE_POSY, 8'h54, 1'b0};
                    7'h08: cmd_reg <= {4'ha, SETTING_TITLE_COLOR, 8'hff, 4'h1, 8'h1};
                    7'h09: cmd_reg <= {4'ha, SETTING_TITLE_POSX + 10'd48, SETTING_TITLE_POSY, 8'h49, 1'b0};
                    7'h0a: cmd_reg <= {4'ha, SETTING_TITLE_COLOR, 8'hff, 4'h1, 8'h1};
                    7'h0b: cmd_reg <= {4'ha, SETTING_TITLE_POSX + 10'd60, SETTING_TITLE_POSY, 8'h4e, 1'b0};
                    7'h0c: cmd_reg <= {4'ha, SETTING_TITLE_COLOR, 8'hff, 4'h1, 8'h1};
                    7'h0d: cmd_reg <= {4'ha, SETTING_TITLE_POSX + 10'd72, SETTING_TITLE_POSY, 8'h47, 1'b0};
                    7'h0e: cmd_reg <= {4'ha, SETTING_TITLE_COLOR, 8'hff, 4'h1, 8'h1};
                    7'h0f: cmd_reg <= {4'ha, SETTING_TITLE_POSX + 10'd84, SETTING_TITLE_POSY, 8'h53, 1'b0};
                    7'h10: cmd_reg <= {4'ha, SETTING_TITLE_COLOR, 8'hff, 4'h1, 8'h1};

                    // MODE:
                    7'h11: cmd_reg <= {4'ha, SETTING_MODE_POSX, SETTING_MODE_POSY, 8'h4d, 1'b0};
                    7'h12: cmd_reg <= {4'ha, setting_color[0], 8'hff, 4'h1, 8'h1};
                    7'h13: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd12, SETTING_MODE_POSY, 8'h4f, 1'b0};
                    7'h14: cmd_reg <= {4'ha, setting_color[0], 8'hff, 4'h1, 8'h1};
                    7'h15: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd24, SETTING_MODE_POSY, 8'h44, 1'b0};
                    7'h16: cmd_reg <= {4'ha, setting_color[0], 8'hff, 4'h1, 8'h1};
                    7'h17: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd36, SETTING_MODE_POSY, 8'h45, 1'b0};
                    7'h18: cmd_reg <= {4'ha, setting_color[0], 8'hff, 4'h1, 8'h1};
                    7'h19: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd60, SETTING_MODE_POSY, 8'h3a, 1'b0};
                    7'h1a: cmd_reg <= {4'ha, setting_color[0], 8'hff, 4'h1, 8'h1};

                    // Classic
                    7'h1b: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd84, SETTING_MODE_POSY, 8'h43, 1'b0};
                    7'h1c: cmd_reg <= {4'ha, setting_color[0], 8'hff, 4'h1, 8'h1};
                    7'h1d: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd96, SETTING_MODE_POSY, 8'h6c, 1'b0};
                    7'h1e: cmd_reg <= {4'ha, setting_color[0], 8'hff, 4'h1, 8'h1};
                    7'h1f: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd108, SETTING_MODE_POSY, 8'h61, 1'b0};
                    7'h20: cmd_reg <= {4'ha, setting_color[0], 8'hff, 4'h1, 8'h1};
                    7'h21: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd120, SETTING_MODE_POSY, 8'h73, 1'b0};
                    7'h22: cmd_reg <= {4'ha, setting_color[0], 8'hff, 4'h1, 8'h1};
                    7'h23: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd132, SETTING_MODE_POSY, 8'h73, 1'b0};
                    7'h24: cmd_reg <= {4'ha, setting_color[0], 8'hff, 4'h1, 8'h1};
                    7'h25: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd144, SETTING_MODE_POSY, 8'h69, 1'b0};
                    7'h26: cmd_reg <= {4'ha, setting_color[0], 8'hff, 4'h1, 8'h1};
                    7'h27: cmd_reg <= {4'ha, SETTING_MODE_POSX + 10'd156, SETTING_MODE_POSY, 8'h63, 1'b0};
                    7'h28: cmd_reg <= {4'ha, setting_color[0], 8'hff, 4'h1, 8'h1};

                    // LEVEL:
                    7'h29: cmd_reg <= {4'ha, SETTING_LEVEL_POSX, SETTING_LEVEL_POSY, 8'h4c, 1'b0};
                    7'h2a: cmd_reg <= {4'ha, setting_color[1], 8'hff, 4'h1, 8'h1};
                    7'h2b: cmd_reg <= {4'ha, SETTING_LEVEL_POSX + 10'd12, SETTING_LEVEL_POSY, 8'h45, 1'b0};
                    7'h2c: cmd_reg <= {4'ha, setting_color[1], 8'hff, 4'h1, 8'h1};
                    7'h2d: cmd_reg <= {4'ha, SETTING_LEVEL_POSX + 10'd24, SETTING_LEVEL_POSY, 8'h56, 1'b0};
                    7'h2e: cmd_reg <= {4'ha, setting_color[1], 8'hff, 4'h1, 8'h1};
                    7'h2f: cmd_reg <= {4'ha, SETTING_LEVEL_POSX + 10'd36, SETTING_LEVEL_POSY, 8'h45, 1'b0};
                    7'h30: cmd_reg <= {4'ha, setting_color[1], 8'hff, 4'h1, 8'h1};
                    7'h31: cmd_reg <= {4'ha, SETTING_LEVEL_POSX + 10'd48, SETTING_LEVEL_POSY, 8'h4c, 1'b0};
                    7'h32: cmd_reg <= {4'ha, setting_color[1], 8'hff, 4'h1, 8'h1};
                    7'h33: cmd_reg <= {4'ha, SETTING_LEVEL_POSX + 10'd60, SETTING_LEVEL_POSY, 8'h3a, 1'b0};
                    7'h34: cmd_reg <= {4'ha, setting_color[1], 8'hff, 4'h1, 8'h1};

                    // 2
                    7'h35: cmd_reg <= {4'ha, SETTING_LEVEL_POSX + 10'd84, SETTING_LEVEL_POSY, 8'h31 + level_reg, 1'b0};
                    7'h36: cmd_reg <= {4'ha, setting_color[1], 8'hff, 4'h1, 8'h1};

                    // MAP:
                    7'h37: cmd_reg <= {4'ha, SETTING_MAP_POSX, SETTING_MAP_POSY, 8'h4d, 1'b0};
                    7'h38: cmd_reg <= {4'ha, setting_color[2], 8'hff, 4'h1, 8'h1};
                    7'h39: cmd_reg <= {4'ha, SETTING_MAP_POSX + 10'd12, SETTING_MAP_POSY, 8'h41, 1'b0};
                    7'h3a: cmd_reg <= {4'ha, setting_color[2], 8'hff, 4'h1, 8'h1};
                    7'h3b: cmd_reg <= {4'ha, SETTING_MAP_POSX + 10'd24, SETTING_MAP_POSY, 8'h50, 1'b0};
                    7'h3c: cmd_reg <= {4'ha, setting_color[2], 8'hff, 4'h1, 8'h1};
                    7'h3d: cmd_reg <= {4'ha, SETTING_MAP_POSX + 10'd60, SETTING_MAP_POSY, 8'h3a, 1'b0};
                    7'h3e: cmd_reg <= {4'ha, setting_color[2], 8'hff, 4'h1, 8'h1};

                    7'h3f: cmd_reg <= {4'ha, SETTING_MAP_POSX + 10'd84, SETTING_MAP_POSY, 8'h4e, 1'b0};
                    7'h40: cmd_reg <= {4'ha, setting_color[2], 8'hff, 4'h1, 8'h1};
                    7'h41: cmd_reg <= {4'ha, SETTING_MAP_POSX + 10'd96, SETTING_MAP_POSY, 8'h6f, 1'b0};
                    7'h42: cmd_reg <= {4'ha, setting_color[2], 8'hff, 4'h1, 8'h1};
                    7'h43: cmd_reg <= {4'ha, SETTING_MAP_POSX + 10'd108, SETTING_MAP_POSY, 8'h6e, 1'b0};
                    7'h44: cmd_reg <= {4'ha, setting_color[2], 8'hff, 4'h1, 8'h1};
                    7'h45: cmd_reg <= {4'ha, SETTING_MAP_POSX + 10'd120, SETTING_MAP_POSY, 8'h65, 1'b0};
                    7'h46: cmd_reg <= {4'ha, setting_color[2], 8'hff, 4'h1, 8'h1};

                    // OK
                    7'h47: cmd_reg <= {4'ha, SETTING_OK_POSX, SETTING_OK_POSY, 8'h4f, 1'b0};
                    7'h48: cmd_reg <= {4'ha, setting_color[3], 8'hff, 4'h1, 8'h1};
                    7'h49: cmd_reg <= {4'ha, SETTING_OK_POSX + 10'd12, SETTING_OK_POSY, 8'h4b, 1'b0};
                    7'h4a: cmd_reg <= {4'ha, setting_color[3], 8'hff, 4'h1, 8'h1};
                    
                    default: cmd_reg <= cmd_reg;
                endcase
            end
            default: begin
                cmd_cnt <= 0;
                cmd_vld_reg <= 0;
            end
        endcase
    end
    else begin
        cmd_vld_reg <= 0;
    end
end

assign start = (ops_id == 1'b0) & (~setting_enb) & right;
assign cmd = cmd_reg;
assign cmd_vld = cmd_vld_reg;

endmodule