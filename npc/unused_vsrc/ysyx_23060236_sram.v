import "DPI-C" function int pmem_read(input int raddr);
import "DPI-C" function void pmem_write(
	  input int waddr, input int wdata, input byte wmask);
module ysyx_23060236_sram(
	input clock,
	input reset,

	input [31:0] araddr,
	input arvalid,
	output arready,

	output reg [31:0] rdata,
	output [1:0] rresp,
	output rvalid,
	input  rready,

	input [31:0] awaddr,
	input awvalid,
	output reg awready,

	input [31:0] wdata,
	input [3:0] wstrb,
	input wvalid,
	output wready,

	output reg [1:0] bresp,
	output bvalid,
	input bready,

	input [7:0] random
);

	wire araddr_valid;
	wire awaddr_valid;
	wire wdata_valid;

	always @(posedge clock) begin
		if (reset) begin
			rdata <= 0;
		end
		else if (arvalid & arready) begin
			rdata <= pmem_read(araddr);
		end
	end

	ysyx_23060236_Reg #(2, 0) reg_rresp(
		.clock(clock),
		.reset(reset),
		.din(0),
		.dout(rresp),
		.wen(arvalid & arready)
	);

	ysyx_23060236_Reg #(1, 0) reg_araddr_valid(
		.clock(clock),
		.reset(reset),
		.din(~araddr_valid & arvalid & arready | araddr_valid & ~(rvalid & rready)),
		.dout(araddr_valid),
		.wen(1)
	);

	/*ysyx_23060236_delay rvalid_delay(
		.clock(clock),
		.reset(reset),
		.data_in(araddr_valid),
		.data_out(rvalid),
		.random(random[3:1])
	);*/
	assign rvalid = araddr_valid;

	ysyx_23060236_Reg #(1, 1) reg_arready(
		.clock(clock),
		.reset(reset),
		.din(~arready & rvalid & rready | arready & ~arvalid),
		.dout(arready),
		.wen(1)
	);

	ysyx_23060236_Reg #(1, 0) reg_awaddr_valid(
		.clock(clock),
		.reset(reset),
		.din(~awaddr_valid & awvalid & awready | awaddr_valid & ~(bvalid & bready)),
		.dout(awaddr_valid),
		.wen(1)
	);

	ysyx_23060236_Reg #(1, 1) reg_awready(
		.clock(clock),
		.reset(reset),
		.din(bvalid & bready | awready & ~awvalid),
		.dout(awready),
		.wen(1)
	);

	reg [31:0] stored_awaddr;
	ysyx_23060236_Reg #(32, 0) reg_awaddr(
		.clock(clock),
		.reset(reset),
		.din(awaddr),
		.dout(stored_awaddr),
		.wen(awvalid & awready)
	);

	ysyx_23060236_Reg #(1, 0) reg_wdata_valid(
		.clock(clock),
		.reset(reset),
		.din(~wdata_valid & wvalid & wready | wdata_valid & ~(bvalid & bready)),
		.dout(wdata_valid),
		.wen(1)
	);

	ysyx_23060236_Reg #(1, 1) reg_wready(
		.clock(clock),
		.reset(reset),
		.din(bvalid & bready | wready & ~wvalid),
		.dout(wready),
		.wen(1)
	);

	reg [31:0] stored_wdata;
	ysyx_23060236_Reg #(32, 0) reg_wdata(
		.clock(clock),
		.reset(reset),
		.din(wdata),
		.dout(stored_wdata),
		.wen(wvalid & wready)
	);

	reg [3:0] stored_wstrb;
	ysyx_23060236_Reg #(4, 0) reg_wstrb(
		.clock(clock),
		.reset(reset),
		.din(wstrb),
		.dout(stored_wstrb),
		.wen(wvalid & wready)
	);

	/*ysyx_23060236_delay bvalid_delay(
		.clock(clock),
		.reset(reset),
		.data_in(awaddr_valid & wdata_valid),
		.data_out(bvalid),
		.random(random[2:0])
	);*/
 assign bvalid = awaddr_valid & wdata_valid;

	always @(bvalid) begin
		if (~reset & bvalid) begin
			pmem_write(stored_awaddr, stored_wdata, {4'b0, stored_wstrb});
			bresp <= 0;
		end
	end
endmodule
