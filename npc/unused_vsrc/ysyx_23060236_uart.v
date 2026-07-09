module ysyx_23060236_uart(
	input  clock,
	input  reset,

	input  [31:0] awaddr,
	input  awvalid,
	output awready,

	input  [31:0] wdata,
	input  [3:0]  wstrb,
	input  wvalid,
	output wready,

	output reg [1:0] bresp,
	output bvalid,
	input  bready
);

	ysyx_23060236_Reg #(1, 1) reg_awready(
		.clock(clock),
		.reset(reset),
		.din(~awready & bvalid & bready | awready & ~awvalid),
		.dout(awready),
		.wen(1)
	);

	wire [31:0] stored_awaddr;
	ysyx_23060236_Reg #(32, 0) reg_stored_awaddr(
		.clock(clock),
		.reset(reset),
		.din(awaddr),
		.dout(stored_awaddr),
		.wen(awvalid & awready)
	);

	ysyx_23060236_Reg #(1, 1) reg_wready(
		.clock(clock),
		.reset(reset),
		.din(~wready & bvalid & bready | wready & ~wvalid),
		.dout(wready),
		.wen(1)
	);

	wire [31:0] stored_wdata;
	ysyx_23060236_Reg #(32, 0) reg_stored_wdata(
		.clock(clock),
		.reset(reset),
		.din(wdata),
		.dout(stored_wdata),
		.wen(wvalid & wready)
	);

	assign bvalid = ~awready & ~wready;

	always @(posedge clock) begin
		if (~reset & bvalid & (stored_awaddr == 32'ha00003f8)) begin
			$write("%c", stored_wdata[7:0]);
			bresp <= 0;
		end
	end

endmodule
