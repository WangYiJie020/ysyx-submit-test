`include "ysyx_23060236_defines.v"
`ifndef SYN
`include "ysyx_23060236_defines_platform.v"
`else
`define ENTRY_ADDR 32'h30000000
`endif
module ysyx_23060236_ifu(
	input  clock,
	input  reset,

	output [31:0] ifu_araddr,
	output        ifu_arvalid,
	input         ifu_arready,
	output [1:0]  ifu_arburst,
	output [3:0]  ifu_arlen,
	input  [31:0] ifu_rdata,
	input  [1:0]  ifu_rresp,
	input         ifu_rlast,
	input         ifu_rvalid,
	output        ifu_rready,

	output [31:0] icache_araddr, //与icache地址位宽一致
	input  [31:0] icache_rdata,
	input         icache_hit,
	output reg [31:0] icache_awaddr, //与icache地址位宽一致
	output reg [31:0] icache_wdata,
	output            icache_wvalid,

	input         wb_valid,
	input         jump_wrong,
	input  [31:0] jump_addr,
	input  [31:0] dnpc,

	output [31:0] pc,
	output reg [31:0] pc_next,
	output reg [31:0] inst,

	output        idu_valid,
	input         idu_ready
);

	wire icache_rvalid;
	wire ifu_valid;
	wire ifu_ready;
	wire ifu_over;
	wire [31:0] inst_tmp;
	wire [31:0] icache_awaddr_tmp; //与icache地址位宽一致
	reg last;
	wire jump_wrong_state;
	wire [31:0] pc_tmp;
	wire is_sram;

	assign is_sram = (pc[31:24] == 8'h0f);

	assign icache_araddr = pc[31:0]; //与icache地址位宽一致
	assign ifu_araddr    = is_sram ? pc : {pc[31:5], 5'b0}; //与icache的块大小一致
	assign ifu_arburst   = 2'b01;
	assign ifu_arlen     = is_sram ? 4'b0000 : 4'b0111; //与icache的块大小一致
	//与icache的块大小一致
	assign inst_tmp = (ifu_rvalid & ifu_rready & (is_sram | (pc[4:2] == icache_awaddr[4:2]))) ? ifu_rdata :
		                (~is_sram & icache_rvalid & icache_hit & ifu_ready) ? icache_rdata :
										inst;
	assign ifu_over = (~is_sram & icache_rvalid & icache_hit & ifu_ready) | (icache_wvalid & last) | (is_sram & ifu_rvalid & ifu_rready);
	assign ifu_valid = idu_valid & idu_ready | (jump_wrong | jump_wrong_state) & (idu_valid | ifu_over);
	assign ifu_ready = ~idu_valid | idu_ready;
	//与icache的块大小一致
	assign icache_awaddr_tmp = (~is_sram & icache_rvalid & ~icache_hit & ifu_ready) ? {pc[31:5], 5'b0} :
														 (~is_sram & icache_wvalid & ~last) ? (icache_awaddr + 4) :
														 icache_awaddr;
	assign pc_tmp = ((jump_wrong | jump_wrong_state) & (idu_valid | ifu_over)) ? jump_addr :
										ifu_over ? dnpc :
										pc;

	always @(posedge clock) begin
		if (ifu_rvalid & ifu_rready) last <= ifu_rlast;
	end

	always @(posedge clock) begin
		if (ifu_over) begin
			pc_next   <= pc;
		end
	end

	ysyx_23060236_Reg #(.WIDTH(32), .RESET_VAL(`ENTRY_ADDR)) pc_adder(
		.clock(clock),
		.reset(reset),
		.din(pc_tmp),
		.dout(pc),
		.wen(1'b1)
	);

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(1)) reg_icache_rvalid(
		.clock(clock),
		.reset(reset),
		.din(ifu_over | icache_rvalid & ~ifu_ready),
		.dout(icache_rvalid),
		.wen(1'b1)
	);

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(0)) reg_icache_wvalid(
		.clock(clock),
		.reset(reset),
		.din(~is_sram & ifu_rvalid & ifu_rready),
		.dout(icache_wvalid),
		.wen(1'b1)
	);

	always @(posedge clock) begin
		icache_awaddr <= icache_awaddr_tmp;
	end

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(1)) reg_ifu_rready(
		.clock(clock),
		.reset(reset),
		.din(ifu_rready & ~ifu_rvalid | icache_wvalid | (is_sram & ifu_over)),
		.dout(ifu_rready),
		.wen(1'b1)
	);

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(0)) reg_ifu_arvalid(
		.clock(clock),
		.reset(reset),
		.din(ifu_arvalid & ~ifu_arready | ~ifu_arvalid & icache_rvalid & ifu_ready & (is_sram | ~icache_hit)),
		.dout(ifu_arvalid),
		.wen(1'b1)
	);

	always @(posedge clock) begin
		if (~is_sram & ifu_rvalid & ifu_rready) icache_wdata <= ifu_rdata;
	end

	always @(posedge clock) begin
		inst <= inst_tmp;
	end

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(0)) reg_idu_valid(
		.clock(clock),
		.reset(reset),
		.din(ifu_over & ~jump_wrong & ~jump_wrong_state | idu_valid & ~idu_ready & ~jump_wrong),
		.dout(idu_valid),
		.wen(1'b1)
	);

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(0)) reg_jump_wrong_state(
		.clock(clock),
		.reset(reset),
		.din(jump_wrong_state & ~ifu_over | ~jump_wrong_state & jump_wrong & ~ifu_over & ~idu_valid),
		.dout(jump_wrong_state),
		.wen(1'b1)
	);

`ifndef __ICARUS__
`ifndef SYN
import "DPI-C" function void add_ifu_readingcycle();
import "DPI-C" function void add_miss_icache();
import "DPI-C" function void add_hit_icache();
import "DPI-C" function void add_tmt();
import "DPI-C" function void add_jump_wrong();
import "DPI-C" function void add_jump_wrong_cycle();
import "DPI-C" function void add_ifu_getinst();

	reg ifu_reading;
	reg ifu_miss_icache;

	always @(posedge clock) begin
		if (reset) ifu_reading <= 1;
		else if (ifu_arvalid) ifu_reading <= 1;
		else if (ifu_rvalid & ifu_rready & ifu_rlast) ifu_reading <= 0;

		if (~reset & (ifu_reading | icache_rvalid & ifu_ready)) add_ifu_readingcycle();

		if (icache_rvalid & ifu_ready) begin
			if (~icache_hit) add_miss_icache();
			else add_hit_icache();
		end

		if (reset) ifu_miss_icache <= 0;
		else if (icache_rvalid & ifu_ready & ~icache_hit) ifu_miss_icache <= 1;
		else if (ifu_over) ifu_miss_icache <= 0;

		if (ifu_miss_icache) add_tmt();

		if (jump_wrong | jump_wrong_state) add_jump_wrong_cycle();
		if (jump_wrong) add_jump_wrong();

		if (ifu_rvalid & ifu_rready | icache_rvalid & ifu_ready & icache_hit) add_ifu_getinst();
	end
`endif
`endif

endmodule
