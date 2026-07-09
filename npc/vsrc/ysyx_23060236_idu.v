`include "ysyx_23060236_defines.v"
module ysyx_23060236_idu(
	input  clock,
	input  reset,

	input  [31:0] in,
	input  [31:0] pc,
	input  [31:0] src1,
	input  [31:0] src2,

	input  [31:0] wb_val,
	input  [3:0]  exu_rd,
	input  exu_reg_wen,
	input  wb_valid,
	input  jump_wrong,

	output [3:0] rs1,
	output [3:0] rs2,

	output reg [31:0] pc_next,
	output reg [9:0]  opcode_type,
	output reg [2:0]  funct3,
	output reg [3:0]  rd,
	output reg [31:0] src1_next,
	output reg [31:0] src2_next,
	output reg [31:0] imm,
	output reg funct7_5,
	output reg reg_wen,
	output reg inst_fencei_idu,
	output reg inst_ecall,
	output reg inst_mret,

	input  idu_valid,
	output idu_ready,
	output exu_valid,
	input  exu_ready
);

	parameter TYPE_R = 0;
	parameter TYPE_I = 1;
	parameter TYPE_S = 2;
	parameter TYPE_B = 3;
	parameter TYPE_U = 4;
	parameter TYPE_J = 5; 

	parameter INST_LUI   = 0;
	parameter INST_AUIPC = 1;
	parameter INST_JAL   = 2;
	parameter INST_JALR  = 3;
	parameter INST_BEQ   = 4;
	parameter INST_LW    = 5;
	parameter INST_SW    = 6;
	parameter INST_ADDI  = 7;
	parameter INST_ADD   = 8;
	parameter INST_CSR   = 9;

	wire [31:0] src1_tmp;
	wire [31:0] src2_tmp;
	wire reg_wen_tmp;
	wire raw_conflict;
	wire need_rs2;
	wire need_rs1;
	wire rs1_exu_conflict;
	wire rs2_exu_conflict;
	wire rs1_idu_conflict;
	wire rs2_idu_conflict;
	wire exu_rdnzero;
	wire idu_rdnzero;

	wire [9:0]  opcode_type_tmp;
	wire [2:0]  funct3_tmp;
	wire [6:0]  funct7_tmp;
	wire [3:0]  rd_tmp;
	wire [31:0] imm_tmp;
	wire inst_fencei_tmp;
	wire inst_ecall_tmp;
	wire inst_mret_tmp;
	wire [5:0] Type;
	wire [4:0] opcode_5;

	assign exu_rdnzero = (exu_rd != 0);
	assign idu_rdnzero = (rd     != 0);
	assign need_rs2 = opcode_type_tmp[INST_BEQ] | opcode_type_tmp[INST_SW] | opcode_type_tmp[INST_ADD];
	assign need_rs1 = need_rs2 | opcode_type_tmp[INST_JALR] | opcode_type_tmp[INST_LW] | opcode_type_tmp[INST_ADDI] | opcode_type_tmp[INST_CSR];
	assign rs1_exu_conflict = (~exu_ready | wb_valid) & need_rs1 & (exu_rd == rs1) & exu_reg_wen & exu_rdnzero;
	assign rs2_exu_conflict = (~exu_ready | wb_valid) & need_rs2 & (exu_rd == rs2) & exu_reg_wen & exu_rdnzero;
	assign rs1_idu_conflict = exu_valid & need_rs1 & (rd == rs1) & reg_wen & idu_rdnzero;
	assign rs2_idu_conflict = exu_valid & need_rs2 & (rd == rs2) & reg_wen & idu_rdnzero;
	assign idu_ready = ~raw_conflict & (exu_ready | ~exu_valid);
	assign src1_tmp = rs1_exu_conflict ? wb_val : src1;
	assign src2_tmp = rs2_exu_conflict ? wb_val : src2;
	assign raw_conflict = (
		~wb_valid & (rs1_exu_conflict | rs2_exu_conflict) |
		(rs1_idu_conflict | rs2_idu_conflict)
	);

	ysyx_23060236_Reg #(.WIDTH(1), .RESET_VAL(0)) reg_exu_valid(
		.clock(clock),
		.reset(reset),
		.din((exu_valid & ~exu_ready | idu_valid & idu_ready) & ~jump_wrong),
		.dout(exu_valid),
		.wen(1'b1)
	);

	always @(posedge clock) begin
		if (reset) begin
			inst_fencei_idu <= 1'b0;
		end
		else if (idu_valid & idu_ready) begin
			opcode_type <= opcode_type_tmp;
			funct3      <= funct3_tmp;
			funct7_5    <= funct7_tmp[5];
			rd          <= rd_tmp;
			imm         <= imm_tmp;
			reg_wen     <= reg_wen_tmp;
			inst_fencei_idu <= inst_fencei_tmp;
			inst_ecall  <= inst_ecall_tmp;
			inst_mret   <= inst_mret_tmp;
			pc_next     <= pc;
			src1_next   <= src1_tmp;
			src2_next   <= src2_tmp;
		end
	end

	assign opcode_5       = in[6:2];
	assign rs1            = in[18:15];
	assign rs2            = in[23:20];
	assign rd_tmp         = in[10:7];
	assign funct3_tmp     = in[14:12];
	assign funct7_tmp     = in[31:25];
	assign reg_wen_tmp    = Type[TYPE_I] & ~((funct3_tmp == 3'b0) & opcode_type_tmp[INST_CSR]) | Type[TYPE_U] | Type[TYPE_J] | Type[TYPE_R];

	assign inst_ecall_tmp  = (in == 32'h00000073);
	assign inst_mret_tmp   = (in == 32'h30200073);
	assign inst_fencei_tmp = (opcode_5 == 5'b00011) & (funct3_tmp == 3'b001);

	assign opcode_type_tmp[INST_LUI  ] = (opcode_5 == 5'b01101);
	assign opcode_type_tmp[INST_AUIPC] = (opcode_5 == 5'b00101);
	assign opcode_type_tmp[INST_JAL  ] = (opcode_5 == 5'b11011);
	assign opcode_type_tmp[INST_JALR ] = (opcode_5 == 5'b11001);
	assign opcode_type_tmp[INST_BEQ  ] = (opcode_5 == 5'b11000);
	assign opcode_type_tmp[INST_LW   ] = (opcode_5 == 5'b00000);
	assign opcode_type_tmp[INST_SW   ] = (opcode_5 == 5'b01000);
	assign opcode_type_tmp[INST_ADDI ] = (opcode_5 == 5'b00100);
	assign opcode_type_tmp[INST_ADD  ] = (opcode_5 == 5'b01100);
	assign opcode_type_tmp[INST_CSR  ] = (opcode_5 == 5'b11100);

	assign Type[TYPE_R] = opcode_type_tmp[INST_ADD];
	assign Type[TYPE_I] = opcode_type_tmp[INST_JALR] | opcode_type_tmp[INST_LW] | opcode_type_tmp[INST_ADDI] | opcode_type_tmp[INST_CSR];
	assign Type[TYPE_S] = opcode_type_tmp[INST_SW];
	assign Type[TYPE_B] = opcode_type_tmp[INST_BEQ];
	assign Type[TYPE_U] = opcode_type_tmp[INST_LUI] | opcode_type_tmp[INST_AUIPC];
	assign Type[TYPE_J] = opcode_type_tmp[INST_JAL];

	assign imm_tmp[31]    = in[31];
	assign imm_tmp[30:20] = Type[TYPE_U] ? in[30:20] : {11{in[31]}};
	assign imm_tmp[19:12] = (Type[TYPE_U] | Type[TYPE_J]) ? in[19:12] : {8{in[31]}};
	assign imm_tmp[11]    = Type[TYPE_B] ? in[7] : 
													Type[TYPE_U] ? 1'b0 : 
													Type[TYPE_J] ? in[20] : 
													in[31];
	assign imm_tmp[10:5] = Type[TYPE_U] ? 6'b0 : in[30:25];
	assign imm_tmp[4:1]  = (Type[TYPE_I] | Type[TYPE_J]) ? in[24:21] : 
												 Type[TYPE_U] ? 4'b0 : 
												 in[11:8];
	assign imm_tmp[0]    = Type[TYPE_I] ? in[20] : 
												 Type[TYPE_S] ? in[7] : 
												 1'b0;


`ifndef __ICARUS__
`ifndef SYN
	import "DPI-C" function void add_raw_conflict();
	import "DPI-C" function void add_raw_conflict_cycle();

	reg raw_conflict_state;
	always @(posedge clock) begin
		if (reset) raw_conflict_state <= 0;
		else raw_conflict_state <= raw_conflict;

		if (raw_conflict) add_raw_conflict_cycle();
		if (~raw_conflict_state & raw_conflict) add_raw_conflict();
	end
`endif
`endif
endmodule
