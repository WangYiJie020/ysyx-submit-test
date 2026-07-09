`include "ysyx_23060236_defines.v"
module ysyx_23060236(
	input  clock,
	input  reset,
	input  io_interrupt,

`ifdef __ICARUS__
	output reg sim_end,
	output [31:0] return_value,
`endif

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

	output        io_slave_awready,
	input         io_slave_awvalid,
	input  [31:0] io_slave_awaddr,
	input  [3:0]  io_slave_awid,
	input  [7:0]  io_slave_awlen,
	input  [2:0]  io_slave_awsize,
	input  [1:0]  io_slave_awburst,

	output        io_slave_wready,
	input         io_slave_wvalid,
	input  [31:0] io_slave_wdata,
	input  [3:0]  io_slave_wstrb,
	input         io_slave_wlast,

	input         io_slave_bready,
	output        io_slave_bvalid,
	output [1:0]  io_slave_bresp,
	output [3:0]  io_slave_bid,

	output        io_slave_arready,
	input         io_slave_arvalid,
	input  [31:0] io_slave_araddr,
	input  [3:0]  io_slave_arid,
	input  [7:0]  io_slave_arlen,
	input  [2:0]  io_slave_arsize,
	input  [1:0]  io_slave_arburst,

	input         io_slave_rready,
	output        io_slave_rvalid,
	output [1:0]  io_slave_rresp,
	output [31:0] io_slave_rdata,
	output        io_slave_rlast,
	output [3:0]  io_slave_rid     

);

	wire [31:0] pc;
	wire [31:0] dnpc;
	wire [31:0] exu_dnpc;
	wire [31:0] ifu_pc;
	wire [31:0] idu_pc;
	wire [15:0] exu_pc; //与btb地址位宽一致
	wire [31:0] jump_addr;
	wire idu_valid;
	wire idu_ready;
	wire exu_valid;
	wire exu_ready;
	wire wb_valid;
	wire jump_wrong;

	wire [31:0] inst;
	wire [9:0]  opcode_type;
	wire [3:0]  rs1;
	wire [3:0]  rs2;
	wire [3:0]  idu_rd;
	wire [3:0]  exu_rd;
	wire [2:0]  funct3;
	wire        funct7_5;
	wire [31:0] imm;
	wire [31:0] src1;
	wire [31:0] src2;
	wire [31:0] idu_src1;
	wire [31:0] idu_src2;
	wire [31:0] wb_val;
	wire idu_reg_wen;
	wire exu_reg_wen;
	wire csr_enable;
	wire inst_ecall;
	wire inst_mret;
	wire inst_fencei_idu;
	wire inst_fencei;
	wire btb_wvalid;

	wire [31:0] csr_jump;
	wire csr_jump_en;

	wire [31:0] csr_wdata;
	wire [31:0] csr_val;
	wire [31:0] exu_val;
	wire lsu_wen;
	wire lsu_ren;

	wire        ifu_arvalid;
	wire [31:0] ifu_araddr;
	wire [31:0] ifu_rdata;
	wire        ifu_arready;
	wire        ifu_rvalid;
	wire [1:0]  ifu_rresp;
	wire        ifu_rlast;
	wire        ifu_rready;
	wire [1:0]  ifu_arburst;
	wire [3:0]  ifu_arlen;

	wire [31:0] lsu_araddr;
	wire        lsu_arvalid;
	wire        lsu_arready;
	wire [31:0] lsu_rdata;
	wire [1:0]  lsu_rresp;
	wire        lsu_rvalid;
	wire        lsu_rready;
	wire [31:0] lsu_awaddr;
	wire        lsu_awvalid;
	wire        lsu_awready;
	wire [31:0] lsu_wdata;
	wire [3:0]  lsu_wstrb;
	wire        lsu_wvalid;
	wire        lsu_wready;
	wire [1:0]  lsu_bresp;
	wire        lsu_bvalid;
	wire        lsu_bready;
	wire [2:0]  lsu_arsize;
	wire [2:0]  lsu_awsize;

	wire [31:0] clint_araddr;
	wire        clint_arvalid;
	wire        clint_arready;
	wire [31:0] clint_rdata;
	wire [1:0]  clint_rresp;
	wire        clint_rvalid;
	wire        clint_rready;

	wire [31:0] icache_araddr; //与icache地址位宽一致
	wire [31:0] icache_rdata;
	wire        icache_hit;
	wire [31:0] icache_awaddr; //与icache地址位宽一致
	wire [31:0] icache_wdata;
	wire        icache_wvalid;

	ysyx_23060236_xbar my_xbar(
		.clock(clock),
		.reset(reset),
		.ifu_araddr(ifu_araddr),
		.ifu_arvalid(ifu_arvalid),
		.ifu_arready(ifu_arready),
		.ifu_arlen(ifu_arlen),
		.ifu_arburst(ifu_arburst),
		.ifu_rdata(ifu_rdata),
		.ifu_rresp(ifu_rresp),
		.ifu_rlast(ifu_rlast),
		.ifu_rvalid(ifu_rvalid),
		.ifu_rready(ifu_rready),
		.lsu_araddr(lsu_araddr),
		.lsu_arvalid(lsu_arvalid),
		.lsu_arready(lsu_arready),
		.lsu_rdata(lsu_rdata),
		.lsu_rresp(lsu_rresp),
		.lsu_rvalid(lsu_rvalid),
		.lsu_rready(lsu_rready),
		.lsu_awaddr(lsu_awaddr),
		.lsu_awvalid(lsu_awvalid),
		.lsu_awready(lsu_awready),
		.lsu_wdata(lsu_wdata),
		.lsu_wstrb(lsu_wstrb),
		.lsu_wvalid(lsu_wvalid),
		.lsu_wready(lsu_wready),
		.lsu_bresp(lsu_bresp),
		.lsu_bvalid(lsu_bvalid),
		.lsu_bready(lsu_bready),
		.lsu_arsize(lsu_arsize),
		.lsu_awsize(lsu_awsize),
		.io_master_awready(io_master_awready),
    .io_master_awvalid(io_master_awvalid),
    .io_master_awaddr(io_master_awaddr),
    .io_master_awid(io_master_awid),
    .io_master_awlen(io_master_awlen),
    .io_master_awsize(io_master_awsize),
    .io_master_awburst(io_master_awburst),
    .io_master_wready(io_master_wready),
    .io_master_wvalid(io_master_wvalid),
    .io_master_wdata(io_master_wdata),
    .io_master_wstrb(io_master_wstrb),
    .io_master_wlast(io_master_wlast),
    .io_master_bready(io_master_bready),
    .io_master_bvalid(io_master_bvalid),
    .io_master_bresp(io_master_bresp),
    .io_master_bid(io_master_bid),
    .io_master_arready(io_master_arready),
    .io_master_arvalid(io_master_arvalid),
    .io_master_araddr(io_master_araddr),
    .io_master_arid(io_master_arid),
    .io_master_arlen(io_master_arlen),
    .io_master_arsize(io_master_arsize),
    .io_master_arburst(io_master_arburst),
    .io_master_rready(io_master_rready),
    .io_master_rvalid(io_master_rvalid),
    .io_master_rresp(io_master_rresp),
    .io_master_rdata(io_master_rdata),
    .io_master_rlast(io_master_rlast),
    .io_master_rid(io_master_rid),
		.clint_araddr(clint_araddr),
		.clint_arvalid(clint_arvalid),
		.clint_arready(clint_arready),
		.clint_rdata(clint_rdata),
		.clint_rresp(clint_rresp),
		.clint_rvalid(clint_rvalid),
		.clint_rready(clint_rready)
	);

	ysyx_23060236_clint my_clint(
		.clock(clock),
		.reset(reset),
		.araddr(clint_araddr),
		.arvalid(clint_arvalid),
		.arready(clint_arready),
		.rdata(clint_rdata),
		.rresp(clint_rresp),
		.rvalid(clint_rvalid),
		.rready(clint_rready)
	);

	ysyx_23060236_icache my_icache(
		.clock(clock),
		.reset(reset),
		.icache_araddr(icache_araddr),
		.icache_rdata(icache_rdata),
		.icache_hit(icache_hit),
		.icache_awaddr(icache_awaddr),
		.icache_wdata(icache_wdata),
		.icache_wvalid(icache_wvalid),
		.inst_fencei(inst_fencei)
	);

	ysyx_23060236_btb_blank my_btb(
		.clock(clock),
		.reset(reset),
		.btb_araddr(pc),
		.btb_rdata(dnpc),
		.btb_araddr_exu(idu_pc),
		.btb_rdata_exu(exu_dnpc),
		.btb_wvalid(btb_wvalid),
		.btb_awaddr(exu_pc),
		.btb_wdata(jump_addr)
	);

	ysyx_23060236_ifu my_ifu(
		.clock(clock),
		.reset(reset),
		.ifu_araddr(ifu_araddr),
		.ifu_arvalid(ifu_arvalid),
		.ifu_arready(ifu_arready),
		.ifu_arlen(ifu_arlen),
		.ifu_arburst(ifu_arburst),
		.ifu_rdata(ifu_rdata),
		.ifu_rresp(ifu_rresp),
		.ifu_rlast(ifu_rlast),
		.ifu_rvalid(ifu_rvalid),
		.ifu_rready(ifu_rready),
		.icache_araddr(icache_araddr),
		.icache_rdata(icache_rdata),
		.icache_hit(icache_hit),
		.icache_awaddr(icache_awaddr),
		.icache_wdata(icache_wdata),
		.icache_wvalid(icache_wvalid),
		.wb_valid(wb_valid),
		.jump_wrong(jump_wrong),
		.dnpc(dnpc),
		.pc(pc),
		.pc_next(ifu_pc),
		.jump_addr(jump_addr),
		.inst(inst),
		.idu_valid(idu_valid),
		.idu_ready(idu_ready)
	);

	ysyx_23060236_idu my_idu(
		.clock(clock),
		.reset(reset),
		.in(inst),
		.pc(ifu_pc),
		.src1(src1),
		.src2(src2),
		.wb_val(wb_val),
		.exu_rd(exu_rd),
		.exu_reg_wen(exu_reg_wen),
		.wb_valid(wb_valid),
		.jump_wrong(jump_wrong),
		.rs1(rs1),
		.rs2(rs2),
		.pc_next(idu_pc),
		.opcode_type(opcode_type),
		.funct3(funct3),
		.funct7_5(funct7_5),
		.rd(idu_rd),
		.src1_next(idu_src1),
		.src2_next(idu_src2),
		.imm(imm),
		.reg_wen(idu_reg_wen),
		.inst_ecall(inst_ecall),
		.inst_mret(inst_mret),
		.inst_fencei_idu(inst_fencei_idu),
		.idu_valid(idu_valid),
		.idu_ready(idu_ready),
		.exu_valid(exu_valid),
		.exu_ready(exu_ready)
	);

	ysyx_23060236_exu my_exu(
		.clock(clock),
		.opcode_type(opcode_type),
		.rd(idu_rd),
		.src1(idu_src1),
		.src2(idu_src2),
		.imm(imm),
		.funct3(funct3),
		.funct7_5(funct7_5),
		.pc(idu_pc),
		.dnpc(exu_dnpc),
		.reg_wen(idu_reg_wen),
		.csr_jump_en(csr_jump_en),
		.csr_jump(csr_jump),
		.csr_val(csr_val),
		.inst_fencei(inst_fencei),
		.inst_fencei_idu(inst_fencei_idu),
		.rd_next(exu_rd),
		.pc_next(exu_pc),
		.reg_wen_next(exu_reg_wen),
		.jump_addr(jump_addr),
		.jump_wrong(jump_wrong),
		.btb_wvalid(btb_wvalid),
		.val(exu_val),
		.lsu_ren(lsu_ren),
		.lsu_wen(lsu_wen),
		.csr_wdata(csr_wdata),
		.csr_enable(csr_enable),
		.exu_valid(exu_valid),
		.exu_ready(exu_ready)
	);

	ysyx_23060236_lsu my_lsu(
		.clock(clock),
		.reset(reset),
		.lsu_araddr(lsu_araddr),
		.lsu_arvalid(lsu_arvalid),
		.lsu_arready(lsu_arready),
		.lsu_rdata(lsu_rdata),
		.lsu_rresp(lsu_rresp),
		.lsu_rvalid(lsu_rvalid),
		.lsu_rready(lsu_rready),
		.lsu_awaddr(lsu_awaddr),
		.lsu_awvalid(lsu_awvalid),
		.lsu_awready(lsu_awready),
		.lsu_wdata(lsu_wdata),
		.lsu_wstrb(lsu_wstrb),
		.lsu_wvalid(lsu_wvalid),
		.lsu_wready(lsu_wready),
		.lsu_bresp(lsu_bresp),
		.lsu_bvalid(lsu_bvalid),
		.lsu_bready(lsu_bready),
		.lsu_arsize(lsu_arsize),
		.lsu_awsize(lsu_awsize),
		.exu_val(exu_val),
		.funct3(funct3),
		.lsu_data(idu_src2),
		.lsu_ren(lsu_ren),
		.lsu_wen(lsu_wen),
		.jump_wrong(jump_wrong),
		.wb_val(wb_val),
		.exu_valid(exu_valid),
		.exu_ready(exu_ready),
		.wb_valid(wb_valid)
	);

	ysyx_23060236_RegisterFile #(4, 32) my_reg(
		.clock(clock),
`ifdef __ICARUS__
		.return_value(return_value),
`endif
		.wdata(wb_val),
		.waddr(exu_rd),
		.rdata1(src1),
		.rdata2(src2),
		.raddr1(rs1),
		.raddr2(rs2),
		.wen(exu_reg_wen),
		.valid(wb_valid)
	);

	ysyx_23060236_CSRFile my_CSRreg(
		.clock(clock),
		.reset(reset),
		.imm(imm[11:0]),
		.wdata(csr_wdata),
		.rdata(csr_val),
		.enable(csr_enable),
		.inst_ecall(inst_ecall),
		.inst_mret(inst_mret),
		.epc(idu_pc),
		.jump(csr_jump),
		.jump_en(csr_jump_en),
		.valid(exu_valid & exu_ready)
	);

	assign io_slave_awready = 0;
	assign io_slave_wready  = 0;
	assign io_slave_bvalid  = 0;
	assign io_slave_bresp   = 0;
	assign io_slave_bid     = 0;
	assign io_slave_arready = 0;
	assign io_slave_rvalid  = 0;
	assign io_slave_rresp   = 0;
	assign io_slave_rdata   = 0;
	assign io_slave_rlast   = 0;
	assign io_slave_rid     = 0;

`ifndef SYN
`ifndef __ICARUS__
import "DPI-C" function void add_total_inst();
import "DPI-C" function void add_total_cycle();
import "DPI-C" function void add_lsu_getdata();
import "DPI-C" function void add_lsu_writedata();

	always @(posedge clock) begin
		add_total_cycle();
		if (wb_valid) add_total_inst();
		if (lsu_rvalid & lsu_rready) add_lsu_getdata();
		if (lsu_bvalid & lsu_bready) add_lsu_writedata();
	end

import "DPI-C" function void record_lsu_awaddr(input int lsu_awaddr);

	always @(posedge clock) begin
		record_lsu_awaddr(lsu_awaddr);
	end

import "DPI-C" function void program_end();

	reg [2:0] prog_end; //1:id, 2:ex, 3:wb
	always @(posedge clock) begin
		if (reset) prog_end <= 0;
		else if ((inst == 32'h00100073) & (idu_valid & idu_ready)) prog_end <= 1;
		else if ((prog_end == 1) & (exu_valid & exu_ready)) prog_end <= 2;
		else if ((prog_end == 2) & wb_valid) program_end();
	end
`else
	reg [2:0] prog_end; //1:id, 2:ex, 3:wb
	always @(posedge clock) begin
		if (reset) begin
			prog_end <= 0;
			sim_end <= 0;
		end
		else if ((inst == 32'h00100073) & (idu_valid & idu_ready)) prog_end <= 1;
		else if ((prog_end == 1) & (exu_valid & exu_ready)) prog_end <= 2;
		else if ((prog_end == 2) & wb_valid) sim_end <= 1;
	end
`endif
`endif

endmodule
