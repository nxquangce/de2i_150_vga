module bcd2ascii(in, out);

input  [3 : 0] in;
output [7 : 0] out;

assign out = 8'h30 + in;

endmodule