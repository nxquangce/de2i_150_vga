module edge_detect(clk, activetype, trigger, out);
input 		clk;
input [1:0] activetype;
input 		trigger;
output		out;

// activetype[1] : output active level
//		+ 0: active LOW
//		+ 1: active HIGH
// activetype[0] : trigger active level
//  	+ 0: LOW (for falling edge)
//		+ 1: HIGH (for rising edge)

reg [2:0] pipe_reg;
wire      trigger_p;
wire      out_p;

assign trigger_p = (activetype[0]) ? trigger : ~trigger;

always @(posedge clk) begin
	pipe_reg[0] <= trigger_p;
	pipe_reg[1] <= pipe_reg[0];
	pipe_reg[2] <= pipe_reg[1];
end

assign out_p = ~pipe_reg[2] & pipe_reg[1];

assign out = (activetype[1]) ? out_p : ~out_p;

endmodule 