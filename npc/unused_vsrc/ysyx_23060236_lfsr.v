module ysyx_23060236_lfsr(
	input clock,
	input reset,
	input enable,
	output [7:0] random
);

reg [7:0] out;

always @(posedge clock) begin
	if (reset) begin
		out <= 8'b00000001;
	end
	else if (enable) begin
		out <= {out[4] ^ out[3] ^ out[2] ^ out[0], out[7:1]};
	end
end

assign random = out;

endmodule
