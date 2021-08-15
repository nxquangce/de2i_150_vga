module draw_char(
    clk,
    rst,
    // USER IF
    x,
    y,
    code,
    size,
    mode,
    idata_bg,
    idata_fg,
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
parameter CHAR_CODE_WIDTH   = 8;

input                           clk;
input                           rst;
input   [PIXEL_X_WIDTH - 1 : 0] x;
input   [PIXEL_Y_WIDTH - 1 : 0] y;
input [CHAR_CODE_WIDTH - 1 : 0] code;
input                     [3:0] size;
input                   [1 : 0] mode;
input  [COLOR_ID_WIDTH - 1 : 0] idata_bg;
input  [COLOR_ID_WIDTH - 1 : 0] idata_fg;
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

reg [CHAR_CODE_WIDTH - 1 : 0] char_reg;
reg                     [3:0] size_reg;
reg  [COLOR_ID_WIDTH - 1 : 0] data_bg;
reg  [COLOR_ID_WIDTH - 1 : 0] data_fg;
reg                           wren;
reg                           vld_start;
reg                           done_reg;
reg                           run;
wire                          done;

reg [PIXEL_X_WIDTH - 1 : 0] posx [4+1:0];
reg [PIXEL_Y_WIDTH - 1 : 0] posy [8+1:0];
reg [4:0] map [8:0];
reg [4:0] active [8:0];
reg fg_valid;

always @(posedge clk) begin
    if (rst) begin
        vld_start <= 0;
        char_reg <= 0;
        size_reg <= 0;
        data_bg <= 0;
        data_fg <= 0;
        x0_physic <= 0;
        y0_physic <= 0;
    end
    else if (idata_vld) begin
        case (mode)
            2'b00: begin
                vld_start <= 0;
                char_reg <= code;
                x0_physic <= x;
                y0_physic <= y;
            end
            2'b01: begin
                vld_start <= 1;
                data_fg <= idata_fg;
                data_bg <= idata_bg;
                size_reg <= size;
            end
            default: begin
                vld_start <= 1;
                char_reg <= code;
                size_reg <= size;
                data_fg <= idata_fg;
                data_bg <= idata_bg;
                x0_physic <= x;
                y0_physic <= y;
            end
        endcase
    end
    else begin
        vld_start <= 0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        x1_physic <= 0;
        y1_physic <= 0;
    end
    else begin
        x1_physic <= x0_physic + ('d5 * (size_reg + 'd1)) + size_reg;
        y1_physic <= y0_physic + ('d9 * (size_reg + 'd1)) + size_reg;
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

integer i, j;
always @(*) begin
    for (i = 0; i < 9; i = i + 1) begin
        for (j = 0; j < 5; j = j + 1) begin
            active[i][j] = map[i][4 - j]
                & ((x_physic >= posx[j]) & (x_physic < posx[j + 1]))
                & ((y_physic >= posy[i]) & (y_physic < posy[i + 1]));
        end
    end
    fg_valid = |{active[0], active[1], active[2], active[3], active[4], active[5], active[6], active[7], active[8]};
end

always @(posedge clk) begin
    if (rst | done) begin
        x_physic <= 0;
        y_physic <= 0;
        wren     <= 0;
    end
    else if (vld_start) begin
        x_physic <= x0_physic;
        y_physic <= y0_physic;
        wren     <= 1;
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
assign odata = (wren) ? (fg_valid) ? data_fg : data_bg : 0;
assign owren = wren;

// Character maps
// xxxxxx
// y01234
// y1..
// y2..
// y:..
// y8..
always @(posedge clk) begin
    posx[0] <= x0_physic + size_reg + 1'b1;
    posx[1] <= x0_physic + ((size_reg + 1'b1) << 1);
    posx[2] <= x0_physic + ((size_reg + 1'b1) << 1) + (size_reg + 1'b1);
    posx[3] <= x0_physic + ((size_reg + 1'b1) << 2);
    posx[4] <= x0_physic + ((size_reg + 1'b1) << 2) + (size_reg + 1'b1);
    posx[5] <= x1_physic + 1;

    posy[0] <= y0_physic + size_reg + 1'b1;
    posy[1] <= y0_physic + ((size_reg + 1'b1) << 1);
    posy[2] <= y0_physic + ((size_reg + 1'b1) << 1) + (size_reg + 1'b1);
    posy[3] <= y0_physic + ((size_reg + 1'b1) << 2);
    posy[4] <= y0_physic + ((size_reg + 1'b1) << 2) + (size_reg + 1'b1);
    posy[5] <= y0_physic + ((size_reg + 1'b1) << 2) + ((size_reg + 1'b1) << 1);
    posy[6] <= y0_physic + ((size_reg + 1'b1) << 2) + ((size_reg + 1'b1) << 1) + (size_reg + 1'b1);
    posy[7] <= y0_physic + ((size_reg + 1'b1) << 3);
    posy[8] <= y0_physic + ((size_reg + 1'b1) << 3) + (size_reg + 1'b1);
    posy[9] <= y1_physic + 1;
end

always @(posedge clk) begin
    case (char_reg)
        8'h30: begin // 0
            map[0] <= 5'b01110;
            map[1] <= 5'b10001;
            map[2] <= 5'b10001;
            map[3] <= 5'b10001;
            map[4] <= 5'b10001;
            map[5] <= 5'b10001;
            map[6] <= 5'b10001;
            map[7] <= 5'b10001;
            map[8] <= 5'b01110;
        end
        8'h31: begin // 1
            map[0] <= 5'b00100;
            map[1] <= 5'b01100;
            map[2] <= 5'b00100;
            map[3] <= 5'b00100;
            map[4] <= 5'b00100;
            map[5] <= 5'b00100;
            map[6] <= 5'b00100;
            map[7] <= 5'b00100;
            map[8] <= 5'b01110;
        end
        8'h32: begin // 2
            map[0] <= 5'b01110;
            map[1] <= 5'b10001;
            map[2] <= 5'b10001;
            map[3] <= 5'b00001;
            map[4] <= 5'b00010;
            map[5] <= 5'b00100;
            map[6] <= 5'b01000;
            map[7] <= 5'b10000;
            map[8] <= 5'b11111;
        end
        8'h33: begin // 3
            map[0] <= 5'b01110;
            map[1] <= 5'b10001;
            map[2] <= 5'b10001;
            map[3] <= 5'b00001;
            map[4] <= 5'b00110;
            map[5] <= 5'b00001;
            map[6] <= 5'b10001;
            map[7] <= 5'b10001;
            map[8] <= 5'b01110;
        end
        8'h34: begin // 4
            map[0] <= 5'b00010;
            map[1] <= 5'b00110;
            map[2] <= 5'b00110;
            map[3] <= 5'b01010;
            map[4] <= 5'b01010;
            map[5] <= 5'b10010;
            map[6] <= 5'b11111;
            map[7] <= 5'b00010;
            map[8] <= 5'b00010;
        end
        8'h35: begin // 5
            map[0] <= 5'b11111;
            map[1] <= 5'b10000;
            map[2] <= 5'b10000;
            map[3] <= 5'b11110;
            map[4] <= 5'b10001;
            map[5] <= 5'b00001;
            map[6] <= 5'b00001;
            map[7] <= 5'b10001;
            map[8] <= 5'b01110;
        end
        8'h36: begin // 6
            map[0] <= 5'b00110;
            map[1] <= 5'b01000;
            map[2] <= 5'b10000;
            map[3] <= 5'b11110;
            map[4] <= 5'b10001;
            map[5] <= 5'b10001;
            map[6] <= 5'b10001;
            map[7] <= 5'b10001;
            map[8] <= 5'b01110;
        end
        8'h37: begin // 7
            map[0] <= 5'b11111;
            map[1] <= 5'b10001;
            map[2] <= 5'b00001;
            map[3] <= 5'b00010;
            map[4] <= 5'b00010;
            map[5] <= 5'b00010;
            map[6] <= 5'b00100;
            map[7] <= 5'b00100;
            map[8] <= 5'b00100;
        end
        8'h38: begin // 8
            map[0] <= 5'b01110;
            map[1] <= 5'b10001;
            map[2] <= 5'b10001;
            map[3] <= 5'b10001;
            map[4] <= 5'b01110;
            map[5] <= 5'b10001;
            map[6] <= 5'b10001;
            map[7] <= 5'b10001;
            map[8] <= 5'b01110;
        end
        8'h39: begin // 9
            map[0] <= 5'b01110;
            map[1] <= 5'b10001;
            map[2] <= 5'b10001;
            map[3] <= 5'b10001;
            map[4] <= 5'b01111;
            map[5] <= 5'b00001;
            map[6] <= 5'b00001;
            map[7] <= 5'b00010;
            map[8] <= 5'b01100;
        end
        8'h3a: begin // :
            map[0] <= 5'b00000;
            map[1] <= 5'b00000;
            map[2] <= 5'b00100;
            map[3] <= 5'b00000;
            map[4] <= 5'b00000;
            map[5] <= 5'b00000;
            map[6] <= 5'b00000;
            map[7] <= 5'b00100;
            map[8] <= 5'b00000;
        end
        8'h41: begin // A
            map[0] <= 5'b00100;
            map[1] <= 5'b01010;
            map[2] <= 5'b10001;
            map[3] <= 5'b10001;
            map[4] <= 5'b11111;
            map[5] <= 5'b10001;
            map[6] <= 5'b10001;
            map[7] <= 5'b10001;
            map[8] <= 5'b10001;
        end
        8'h43: begin // C
            map[0] <= 5'b01110;
            map[1] <= 5'b10001;
            map[2] <= 5'b10000;
            map[3] <= 5'b10000;
            map[4] <= 5'b10000;
            map[5] <= 5'b10000;
            map[6] <= 5'b10000;
            map[7] <= 5'b10001;
            map[8] <= 5'b01110;
        end
        8'h44: begin // D
            map[0] <= 5'b11110;
            map[1] <= 5'b10001;
            map[2] <= 5'b10001;
            map[3] <= 5'b10001;
            map[4] <= 5'b10001;
            map[5] <= 5'b10001;
            map[6] <= 5'b10001;
            map[7] <= 5'b10001;
            map[8] <= 5'b11110;
        end
        8'h45: begin // E
            map[0] <= 5'b11111;
            map[1] <= 5'b10000;
            map[2] <= 5'b10000;
            map[3] <= 5'b10000;
            map[4] <= 5'b11111;
            map[5] <= 5'b10000;
            map[6] <= 5'b10000;
            map[7] <= 5'b10000;
            map[8] <= 5'b11111;
        end
        8'h47: begin // G
            map[0] <= 5'b01110;
            map[1] <= 5'b10001;
            map[2] <= 5'b10000;
            map[3] <= 5'b10000;
            map[4] <= 5'b10000;
            map[5] <= 5'b10111;
            map[6] <= 5'b10001;
            map[7] <= 5'b10011;
            map[8] <= 5'b01101;
        end
        8'h49: begin // I
            map[0] <= 5'b01110;
            map[1] <= 5'b00100;
            map[2] <= 5'b00100;
            map[3] <= 5'b00100;
            map[4] <= 5'b00100;
            map[5] <= 5'b00100;
            map[6] <= 5'b00100;
            map[7] <= 5'b00100;
            map[8] <= 5'b01110;
        end
        8'h4C: begin // L
            map[0] <= 5'b10000;
            map[1] <= 5'b10000;
            map[2] <= 5'b10000;
            map[3] <= 5'b10000;
            map[4] <= 5'b10000;
            map[5] <= 5'b10000;
            map[6] <= 5'b10000;
            map[7] <= 5'b10000;
            map[8] <= 5'b11111;
        end
        8'h4D: begin // M
            map[0] <= 5'b10001;
            map[1] <= 5'b11011;
            map[2] <= 5'b10101;
            map[3] <= 5'b10001;
            map[4] <= 5'b10001;
            map[5] <= 5'b10001;
            map[6] <= 5'b10001;
            map[7] <= 5'b10001;
            map[8] <= 5'b10001;
        end
        8'h4E: begin // N
            map[0] <= 5'b10001;
            map[1] <= 5'b11001;
            map[2] <= 5'b10101;
            map[3] <= 5'b10011;
            map[4] <= 5'b10001;
            map[5] <= 5'b10001;
            map[6] <= 5'b10001;
            map[7] <= 5'b10001;
            map[8] <= 5'b10001;
        end
        8'h4B: begin // K
            map[0] <= 5'b10001;
            map[1] <= 5'b10010;
            map[2] <= 5'b10100;
            map[3] <= 5'b11000;
            map[4] <= 5'b11000;
            map[5] <= 5'b10100;
            map[6] <= 5'b10010;
            map[7] <= 5'b10001;
            map[8] <= 5'b10001;
        end
        8'h4F: begin // O
            map[0] <= 5'b01110;
            map[1] <= 5'b10001;
            map[2] <= 5'b10001;
            map[3] <= 5'b10001;
            map[4] <= 5'b10001;
            map[5] <= 5'b10001;
            map[6] <= 5'b10001;
            map[7] <= 5'b10001;
            map[8] <= 5'b01110;
        end
        8'h50: begin // P
            map[0] <= 5'b11110;
            map[1] <= 5'b10001;
            map[2] <= 5'b10001;
            map[3] <= 5'b10001;
            map[4] <= 5'b11110;
            map[5] <= 5'b10000;
            map[6] <= 5'b10000;
            map[7] <= 5'b10000;
            map[8] <= 5'b10000;
        end
        8'h52: begin // R
            map[0] <= 5'b11110;
            map[1] <= 5'b10001;
            map[2] <= 5'b10001;
            map[3] <= 5'b10001;
            map[4] <= 5'b11110;
            map[5] <= 5'b10100;
            map[6] <= 5'b10010;
            map[7] <= 5'b10001;
            map[8] <= 5'b10001;
        end
        8'h53: begin // S
            map[0] <= 5'b01110;
            map[1] <= 5'b10001;
            map[2] <= 5'b10000;
            map[3] <= 5'b11000;
            map[4] <= 5'b01110;
            map[5] <= 5'b00011;
            map[6] <= 5'b00001;
            map[7] <= 5'b10001;
            map[8] <= 5'b01110;
        end
        8'h54: begin // T
            map[0] <= 5'b11111;
            map[1] <= 5'b00100;
            map[2] <= 5'b00100;
            map[3] <= 5'b00100;
            map[4] <= 5'b00100;
            map[5] <= 5'b00100;
            map[6] <= 5'b00100;
            map[7] <= 5'b00100;
            map[8] <= 5'b00100;
        end
        8'h56: begin // V
            map[0] <= 5'b10001;
            map[1] <= 5'b10001;
            map[2] <= 5'b10001;
            map[3] <= 5'b10001;
            map[4] <= 5'b10001;
            map[5] <= 5'b10001;
            map[6] <= 5'b10001;
            map[7] <= 5'b01010;
            map[8] <= 5'b00100;
        end
        8'h59: begin // Y
            map[0] <= 5'b10001;
            map[1] <= 5'b10001;
            map[2] <= 5'b01010;
            map[3] <= 5'b01010;
            map[4] <= 5'b00100;
            map[5] <= 5'b00100;
            map[6] <= 5'b00100;
            map[7] <= 5'b00100;
            map[8] <= 5'b00100;
        end
        8'h61: begin // a
            map[0] <= 5'b0000;
            map[1] <= 5'b00000;
            map[2] <= 5'b01110;
            map[3] <= 5'b10001;
            map[4] <= 5'b00111;
            map[5] <= 5'b01001;
            map[6] <= 5'b10001;
            map[7] <= 5'b10011;
            map[8] <= 5'b01101;
        end
        8'h65: begin // e
            map[0] <= 5'b00000;
            map[1] <= 5'b00000;
            map[2] <= 5'b01110;
            map[3] <= 5'b10001;
            map[4] <= 5'b10001;
            map[5] <= 5'b11110;
            map[6] <= 5'b10000;
            map[7] <= 5'b10001;
            map[8] <= 5'b01110;
        end
        8'h6E: begin // n
            map[0] <= 5'b00000;
            map[1] <= 5'b00000;
            map[2] <= 5'b10110;
            map[3] <= 5'b11001;
            map[4] <= 5'b10001;
            map[5] <= 5'b10001;
            map[6] <= 5'b10001;
            map[7] <= 5'b10001;
            map[8] <= 5'b10001;
        end
        8'h6F: begin // o
            map[0] <= 5'b00000;
            map[1] <= 5'b00000;
            map[2] <= 5'b01110;
            map[3] <= 5'b10001;
            map[4] <= 5'b10001;
            map[5] <= 5'b10001;
            map[6] <= 5'b10001;
            map[7] <= 5'b10001;
            map[8] <= 5'b01110;
        end
        8'h73: begin // s
            map[0] <= 5'b0000;
            map[1] <= 5'b00000;
            map[2] <= 5'b01110;
            map[3] <= 5'b10001;
            map[4] <= 5'b10000;
            map[5] <= 5'b01110;
            map[6] <= 5'b00001;
            map[7] <= 5'b10001;
            map[8] <= 5'b01110;
        end
        8'h63: begin // c
            map[0] <= 5'b0000;
            map[1] <= 5'b00000;
            map[2] <= 5'b01110;
            map[3] <= 5'b10001;
            map[4] <= 5'b10000;
            map[5] <= 5'b10000;
            map[6] <= 5'b10000;
            map[7] <= 5'b10001;
            map[8] <= 5'b01110;
        end
        8'h69: begin // i
            map[0] <= 5'b00100;
            map[1] <= 5'b00000;
            map[2] <= 5'b01100;
            map[3] <= 5'b00100;
            map[4] <= 5'b00100;
            map[5] <= 5'b00100;
            map[6] <= 5'b00100;
            map[7] <= 5'b00100;
            map[8] <= 5'b01110;
        end
        8'h6C: begin // l
            map[0] <= 5'b11000;
            map[1] <= 5'b01000;
            map[2] <= 5'b01000;
            map[3] <= 5'b01000;
            map[4] <= 5'b01000;
            map[5] <= 5'b01000;
            map[6] <= 5'b01000;
            map[7] <= 5'b01000;
            map[8] <= 5'b00110;
        end
        8'h76: begin // v
            map[0] <= 5'b00000;
            map[1] <= 5'b00000;
            map[2] <= 5'b10001;
            map[3] <= 5'b10001;
            map[4] <= 5'b10001;
            map[5] <= 5'b10001;
            map[6] <= 5'b10001;
            map[7] <= 5'b01010;
            map[8] <= 5'b00100;
        end
        8'h80: begin // up arrow - custom
            map[0] <= 5'b00100;
            map[1] <= 5'b01110;
            map[2] <= 5'b10101;
            map[3] <= 5'b00100;
            map[4] <= 5'b00100;
            map[5] <= 5'b00100;
            map[6] <= 5'b00100;
            map[7] <= 5'b00100;
            map[8] <= 5'b00100;
        end
        8'h81: begin // down arrow - custom
            map[0] <= 5'b00100;
            map[1] <= 5'b00100;
            map[2] <= 5'b00100;
            map[3] <= 5'b00100;
            map[4] <= 5'b00100;
            map[5] <= 5'b00100;
            map[6] <= 5'b10101;
            map[7] <= 5'b01110;
            map[8] <= 5'b00100;
        end
        default: begin
            map[0] <= 5'b00000;
            map[1] <= 5'b00000;
            map[2] <= 5'b00000;
            map[3] <= 5'b00000;
            map[4] <= 5'b00000;
            map[5] <= 5'b00000;
            map[6] <= 5'b00000;
            map[7] <= 5'b00000;
            map[8] <= 5'b01111;
        end
    endcase
end

endmodule