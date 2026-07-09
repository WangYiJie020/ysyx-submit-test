`include "ysyx_23060236_defines.v"
module ysyx_23060236_xbar(
	input  clock,
	input  reset,

	input  [31:0] ifu_araddr,
	input         ifu_arvalid,
	output        ifu_arready,
	input  [1:0]  ifu_arburst,
	input  [3:0]  ifu_arlen,

	output [31:0] ifu_rdata,
	output [1:0]  ifu_rresp,
	output        ifu_rlast,
	output        ifu_rvalid,
	input         ifu_rready,
	
	input  [31:0] lsu_araddr,
	input         lsu_arvalid,
	input  [2:0]  lsu_arsize,
	output        lsu_arready,

	output [31:0] lsu_rdata,
	output [1:0]  lsu_rresp,
	output        lsu_rvalid,
	input         lsu_rready,

	input  [31:0] lsu_awaddr,
	input         lsu_awvalid,
	input  [2:0]  lsu_awsize,
	output        lsu_awready,

	input  [31:0] lsu_wdata,
	input  [3:0]  lsu_wstrb,
	input         lsu_wvalid,
	output        lsu_wready,

	output [1:0]  lsu_bresp,
	output        lsu_bvalid,
	input         lsu_bready,


	input         io_master_awready,
	output        io_master_awvalid,
	output [31:0] io_master_awaddr,
	output [3:0]  io_master_awid,
	output [7:0]  io_master_awlen,
	output [2:0]  io_master_awsize,
	output [1:0]  io_master_awburst,
	
	input         io_master_wready,
	output        io_master_wvalid,
	output [31:0] io_master_wdata,
	output [3:0]  io_master_wstrb,
	output        io_master_wlast,
	
	output        io_master_bready,
	input         io_master_bvalid,
	input  [1:0]  io_master_bresp,
	input  [3:0]  io_master_bid,
	
	input         io_master_arready,
	output        io_master_arvalid,
	output [31:0] io_master_araddr,
	output [3:0]  io_master_arid,
	output [7:0]  io_master_arlen,
	output [2:0]  io_master_arsize,
	output [1:0]  io_master_arburst,
	
	output        io_master_rready,
	input         io_master_rvalid,
	input  [1:0]  io_master_rresp,
	input  [31:0] io_master_rdata,
	input         io_master_rlast,
	input  [3:0]  io_master_rid,


	output [31:0] clint_araddr,
	output        clint_arvalid,
	input         clint_arready,

	input  [31:0] clint_rdata,
	input  [1:0]  clint_rresp,
	input         clint_rvalid,
	output        clint_rready
);

	wire ifu_reading, lsu_reading;
	wire soc_reading, clint_reading;

	assign soc_reading = ~clint_reading;
	assign clint_reading = (lsu_araddr >= 32'h02000000) & (lsu_araddr < 32'h02010000);

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(0)) state_ifu_reading(
		.clock(clock),
		.reset(reset),
		.din(~ifu_reading & ~lsu_arvalid & ~lsu_reading & ifu_arvalid | ifu_reading & ~(ifu_rvalid & ifu_rready & ifu_rlast)),
		.dout(ifu_reading),
		.wen(1'b1)
	);

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(0)) state_lsu_reading(
		.clock(clock),
		.reset(reset),
		.din(~lsu_reading & ~ifu_reading & lsu_arvalid | lsu_reading & ~(lsu_rvalid & lsu_rready)),
		.dout(lsu_reading),
		.wen(1'b1)
	);

	assign ifu_arready       = ifu_reading & io_master_arready;
	assign lsu_arready       = lsu_reading & (soc_reading & io_master_arready | clint_reading & clint_arready);
	assign io_master_arvalid = ifu_reading & ifu_arvalid | lsu_reading & soc_reading & lsu_arvalid;
	assign clint_arvalid     = lsu_reading & clint_reading & lsu_arvalid;
	assign io_master_araddr  = {32{ifu_reading}} & ifu_araddr | {32{lsu_reading}} & {32{soc_reading}} & lsu_araddr;
	assign clint_araddr      = {32{lsu_reading}} & {32{clint_reading}} & lsu_araddr;
	assign io_master_arid    = 0;
	assign io_master_arlen   = {4'b0, {{4{ifu_reading}} & ifu_arlen}};
	assign io_master_arsize  = {3{ifu_reading}} & 3'b010 | {3{lsu_reading}} & lsu_arsize;
	assign io_master_arburst = {2{ifu_reading}} & ifu_arburst;

	assign io_master_rready  = ifu_reading & ifu_rready | lsu_reading & lsu_rready & soc_reading;
	assign clint_rready      = lsu_reading & clint_reading & lsu_rready;
	assign ifu_rvalid        = ifu_reading & io_master_rvalid;
	assign lsu_rvalid        = lsu_reading & (soc_reading & io_master_rvalid | clint_reading & clint_rvalid);
	assign ifu_rresp         = {2{ifu_reading}} & io_master_rresp;
	assign ifu_rlast         = ifu_reading & io_master_rlast;
	assign lsu_rresp         = {2{lsu_reading}} & ({2{soc_reading}} & io_master_rresp | {2{clint_reading}} & clint_rresp);
	assign ifu_rdata         = {32{ifu_reading}} & io_master_rdata;
	assign lsu_rdata         = {32{lsu_reading}} & ({32{soc_reading}} & io_master_rdata | {32{clint_reading}} & clint_rdata);

	assign lsu_awready       = io_master_awready;
	assign io_master_awvalid = lsu_awvalid;
	assign io_master_awaddr  = lsu_awaddr;
	assign io_master_awid    = 0;
	assign io_master_awlen   = 0;
	assign io_master_awsize  = lsu_awsize;
	assign io_master_awburst = 0;

	assign lsu_wready        = io_master_wready;
	assign io_master_wvalid  = lsu_wvalid;
	assign io_master_wdata   = lsu_wdata;
	assign io_master_wstrb   = lsu_wstrb;
	assign io_master_wlast   = io_master_wvalid;

	assign io_master_bready  = lsu_bready;
	assign lsu_bvalid        = io_master_bvalid;
	assign lsu_bresp         = io_master_bresp;

`ifndef __ICARUS__
`ifndef SYN
import "DPI-C" function void add_lsu_readingcycle();
import "DPI-C" function void add_lsu_writingcycle();

	reg lsu_writing;

	always @(posedge clock) begin
		if (reset) lsu_writing <= 0;
		else if (lsu_awvalid) lsu_writing <= 1;
		else if (lsu_bvalid & lsu_bready) lsu_writing <= 0;

		if (lsu_writing) add_lsu_writingcycle();
		if (lsu_reading) add_lsu_readingcycle();
	end
`endif
`endif
endmodule
