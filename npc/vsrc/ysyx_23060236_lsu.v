`include "ysyx_23060236_defines.v"
module ysyx_23060236_lsu(
	input  clock,
	input  reset,

	output [31:0] lsu_araddr,
	output        lsu_arvalid,
	output [2:0]  lsu_arsize,
	input         lsu_arready,
	input  [31:0] lsu_rdata,
	input  [1:0]  lsu_rresp,
	input         lsu_rvalid,
	output        lsu_rready,

	output [31:0] lsu_awaddr,
	output        lsu_awvalid,
	output [2:0]  lsu_awsize,
	input         lsu_awready,
	output [31:0] lsu_wdata,
	output [3:0]  lsu_wstrb,
	output        lsu_wvalid,
	input         lsu_wready,
	input  [1:0]  lsu_bresp,
	input         lsu_bvalid,
	output        lsu_bready,

	input  [31:0] exu_val,
	input  [2:0]  funct3,
	input  [31:0] lsu_data,
	input  lsu_ren,
	input  lsu_wen,
	input  jump_wrong,

	output reg [31:0] wb_val,

	input  exu_valid,
	output exu_ready,
	output wb_valid
);

	reg  [2:0]  funct3_reg;
	reg  [31:0] lsu_data_reg;
	wire [31:0] lsu_addr;
	wire [3:0]  wmask;
	wire lsu_over;
	wire exu_ready_tmp;

	wire [31:0] lsu_val_tmp;
	wire [31:0] lsu_val_shift;

	assign exu_ready = exu_ready_tmp & ~jump_wrong;
	assign lsu_over = exu_valid & exu_ready & ~lsu_ren & ~lsu_wen | lsu_rvalid & lsu_rready | lsu_bvalid & lsu_bready;
	assign lsu_addr = wb_val;
	assign wmask = (funct3_reg[1:0] == 2'b00) ? 4'h1 : 
								 (funct3_reg[1:0] == 2'b01) ? 4'h3 :
								 (funct3_reg[1:0] == 2'b10) ? 4'hf : 
								 4'b0;

	always @(posedge clock) begin
		if (exu_valid & exu_ready) begin
			wb_val          <= exu_val;
			funct3_reg      <= funct3;
			lsu_data_reg    <= lsu_data;
		end
		else if (lsu_rvalid & lsu_rready) begin
			wb_val <= lsu_val_tmp;
		end
	end

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(1)) reg_exu_ready_tmp(
		.clock(clock),
		.reset(reset),
		.din(exu_ready_tmp & ~(exu_ready & exu_valid) | lsu_over),
		.dout(exu_ready_tmp),
		.wen(1'b1)
	);

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(0)) reg_wb_valid(
		.clock(clock),
		.reset(reset),
		.din(lsu_over),
		.dout(wb_valid),
		.wen(1'b1)
	);

	assign lsu_arsize = {1'b0, funct3_reg[1:0]};
	assign lsu_awsize = {1'b0, funct3_reg[1:0]};
	assign lsu_rready = 1;
	assign lsu_bready = 1;
	assign lsu_araddr = lsu_addr;
	assign lsu_awaddr = lsu_addr;
	assign lsu_wstrb  = wmask << lsu_awaddr[1:0];
	assign lsu_wdata  = lsu_data_reg << {lsu_awaddr[1:0], 3'b0};
	assign lsu_val_shift = lsu_rdata >> {lsu_araddr[1:0], 3'b0};

	assign lsu_val_tmp = (funct3_reg == 3'b000) ? (lsu_val_shift & 32'hff) | {{24{lsu_val_shift[7]}}, 8'h0} :     //lb  
                       (funct3_reg == 3'b001) ? (lsu_val_shift & 32'hffff) | {{16{lsu_val_shift[15]}}, 16'h0} : //lh
                       (funct3_reg == 3'b010) ? lsu_val_shift :                                                 //lw
                       (funct3_reg == 3'b100) ? lsu_val_shift & 32'hff :                                        //lbu
                       (funct3_reg == 3'b101) ? lsu_val_shift & 32'hffff :                                      //lhu
											 32'b0;

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(0)) reg_lsu_arvalid(
		.clock(clock),
		.reset(reset),
		.din(lsu_arvalid & ~lsu_arready | ~lsu_arvalid & lsu_ren & exu_valid & exu_ready),
		.dout(lsu_arvalid),
		.wen(1'b1)
	);

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(0)) reg_lsu_awvalid(
		.clock(clock),
		.reset(reset),
		.din(lsu_awvalid & ~lsu_awready | ~lsu_awvalid & lsu_wen & exu_valid & exu_ready),
		.dout(lsu_awvalid),
		.wen(1'b1)
	);

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(0)) reg_lsu_wvalid(
		.clock(clock),
		.reset(reset),
		.din(lsu_wvalid & ~lsu_wready | ~lsu_wvalid & lsu_wen & exu_valid & exu_ready),
		.dout(lsu_wvalid),
		.wen(1'b1)
	);

endmodule
