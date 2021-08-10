module bin2bcd(in, out);

parameter BIT_WIDTH     = 8;
parameter NUM_BCD       = 3;

localparam OUT_WIDTH    = 4 * NUM_BCD;

input [BIT_WIDTH - 1 : 0] in;
output [OUT_WIDTH - 1 : 0] out;

genvar i;
generate
    for (i = 1; i < NUM_BCD; i = i + 1) begin: out_gen
        assign out[4 * (i + 1) - 1 : 4 * i] = (in < ('d10 ** i)) ? 0 : (in / ('d10 ** i)) % 'd10;
    end
endgenerate

assign out[3 : 0] = in % 'd10;

endmodule 