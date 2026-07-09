module ysyx_23060236_delay #(DELAY = 15) (
	input  clock,
	input  reset,
	input  data_in,
	input  [2:0] random,
	output data_out
);

	reg [DELAY-1:0] data_buf;

	always @(posedge clock) begin
		if (reset) begin
			data_buf <= 0;
		end
		else begin
			data_buf <= {DELAY{data_in}} & {data_buf[DELAY-2:0], data_in};
		end
	end

	assign data_out = data_buf[DELAY-1-random];

endmodule
