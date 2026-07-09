module ysyx_23060236_btb(
	input clock,
	input reset,

	input  [DATA_LEN-1:0] btb_araddr,
	output [DATA_LEN-1:0] btb_rdata,
	input  [DATA_LEN-1:0] btb_araddr_exu,
	output [DATA_LEN-1:0] btb_rdata_exu,

	input  btb_wvalid,
	input  [ADDR_LEN-1:0] btb_awaddr,
	input  [DATA_LEN-1:0] btb_wdata
);

	//此处ADDR_LEN减7与sdram地址范围匹配
	localparam ADDR_LEN   = 32 - 7;
	localparam DATA_LEN   = 32;
	localparam OFFSET_LEN = 2;
	localparam INDEX_LEN  = 0;
	localparam TAG_LEN    = ADDR_LEN - OFFSET_LEN - INDEX_LEN;

	reg [DATA_LEN-1:0] btb_data ;
	reg [TAG_LEN-1:0]  btb_tag  ;
	reg btb_valid;

	wire btb_hit;
	wire [TAG_LEN-1:0] read_tag;
	wire [TAG_LEN-1:0] write_tag;
	wire btb_hit_exu;
	wire [TAG_LEN-1:0] read_tag_exu;

	assign read_tag     = btb_araddr[ADDR_LEN-1 : OFFSET_LEN+INDEX_LEN];
	assign write_tag    = btb_awaddr[ADDR_LEN-1 : OFFSET_LEN+INDEX_LEN];
	assign btb_hit      = btb_valid & (btb_tag == read_tag);
	assign btb_rdata    = btb_hit ? btb_data : (btb_araddr + 4);

	assign read_tag_exu  = btb_araddr_exu[ADDR_LEN-1 : OFFSET_LEN+INDEX_LEN];
	assign btb_hit_exu   = btb_valid & (btb_tag == read_tag_exu);
	assign btb_rdata_exu = btb_hit_exu ? btb_data : (btb_araddr_exu + 4);

	always @(posedge clock) begin
		if (reset) btb_valid <= 0;
		else if (btb_wvalid) btb_valid <= 1'b1;
	end

	always @(posedge clock) begin
		if (btb_wvalid) btb_data <= btb_wdata;
	end

	always @(posedge clock) begin
		if (btb_wvalid) btb_tag <= write_tag;
	end

endmodule
module ysyx_23060236_clint(
	input  clock,
	input  reset,

	input  [31:0] araddr,
	input  arvalid,
	output arready,

	output [31:0] rdata,
	output [1:0]  rresp,
	output rvalid,
	input  rready
);

	wire [63:0] mtime;
	wire idle;
	reg  high_data;
	
	assign rdata = high_data ? mtime[63:32] : mtime[31:0];
	assign rresp = 0;
	assign arready = idle;
	assign rvalid = ~idle;

	always @(posedge clock) begin
		if (arvalid & arready) high_data <= araddr[2];
	end

	ysyx_23060236_Reg #(1, 1) reg_idle(
		.clock(clock),
		.reset(reset),
		.din(idle & ~arvalid | ~idle & rready),
		.dout(idle),
		.wen(1)
	);

	ysyx_23060236_Reg #(64, 0) reg_mtime(
		.clock(clock),
		.reset(reset),
		.din(mtime + 1),
		.dout(mtime),
		.wen(1)
	);

endmodule
module ysyx_23060236_CSRFile (
	input  clock,
	input  reset,
	input  [11:0] imm,
	input  [31:0] wdata,
	output [31:0] rdata,
	input  enable,
	input  inst_ecall,
	input  inst_mret,
	input  [31:0] epc,
	output [31:0] jump,
	output        jump_en,
	input  valid
);

	reg [31:0] mepc   ;
	reg [6:0]  mcause ;
	reg [31:0] mstatus;
	reg [31:0] mtvec  ;

	wire [5:0] choose;

	localparam CSR_MEPC      = 0;
	localparam CSR_MCAUSE    = 1;
	localparam CSR_MSTATUS   = 2;
	localparam CSR_MTVEC     = 3;
	localparam CSR_MVENDORID = 4;
	localparam CSR_MARCHID   = 5;

	assign choose[CSR_MEPC     ] = (imm == 12'h341);
	assign choose[CSR_MCAUSE   ] = (imm == 12'h342);
	assign choose[CSR_MSTATUS  ] = (imm == 12'h300);
	assign choose[CSR_MTVEC    ] = (imm == 12'h305);
	assign choose[CSR_MVENDORID] = (imm == 12'hf11);
	assign choose[CSR_MARCHID  ] = (imm == 12'hf12);

	always @(posedge clock) begin
		if (reset) begin
			mstatus <= 32'h1800;
		end
		else if (valid) begin
			if (enable) begin
				if (choose[CSR_MEPC     ]) mepc    <= wdata;
				if (choose[CSR_MCAUSE   ]) mcause  <= {wdata[31], wdata[5:0]};
				if (choose[CSR_MSTATUS  ]) mstatus <= wdata;
				if (choose[CSR_MTVEC    ]) mtvec   <= wdata;
			end
			else if (inst_ecall) begin
				mepc   <= epc;
				mcause <= 7'd11;
			end
		end
	end

	assign rdata = choose[CSR_MEPC     ] ? mepc    :
                 choose[CSR_MCAUSE   ] ? {mcause[6], 25'b0, mcause[5:0]} :
                 choose[CSR_MSTATUS  ] ? mstatus :
                 choose[CSR_MTVEC    ] ? mtvec   :
                 choose[CSR_MVENDORID] ? 32'h79737978 :
                 choose[CSR_MARCHID  ] ? 32'h015fdf0c :
								 32'b0;

	assign jump = {32{inst_ecall}} & mtvec | {32{inst_mret}} & mepc;
	assign jump_en = inst_ecall | inst_mret;

endmodule
module ysyx_23060236_exu(
	input  clock,

	input  [9:0]  opcode_type,
	input  [3:0]  rd,
	input  [31:0] src1,
	input  [31:0] src2,
	input  [31:0] imm,
	input  [2:0]  funct3,
	input         funct7_5,
	input  [31:0] pc,
	input  [31:0] dnpc,
	input  reg_wen,
	input  csr_jump_en,
	input  [31:0] csr_jump,
	input  [31:0] csr_val,
	input  inst_fencei,

	output reg [3:0]  rd_next,
	output reg [24:0] pc_next, //与btb地址位宽一致
	output reg reg_wen_next,
	output reg [31:0] jump_addr,
	output jump_wrong,
	output btb_wvalid,

	output [31:0] val,
	output lsu_ren,
	output lsu_wen,
	output [31:0] csr_wdata,
	output csr_enable,

	input  exu_valid,
	input  exu_ready
);

	wire [31:0] jump_addr_tmp;
	wire [31:0] alu_val;
	wire [31:0] snpc;
	wire jump_en;
	wire jal_enable;
	reg  need_btb;
	reg  jump_wrong_tmp;
	reg  inst_fencei_tmp;

	assign btb_wvalid = jump_wrong & need_btb;
	assign snpc = pc + 4;
	assign csr_enable = opcode_type[INST_CSR] & (funct3 != 3'b0);
	assign jal_enable = opcode_type[INST_JAL] | opcode_type[INST_JALR];
	assign lsu_ren = opcode_type[INST_LW];
	assign lsu_wen = opcode_type[INST_SW];
	assign jump_wrong = inst_fencei_tmp | jump_wrong_tmp;

	always @(posedge clock) begin
		if (exu_valid & exu_ready) begin
			rd_next         <= rd;
			reg_wen_next    <= reg_wen;
			jump_addr       <= jump_addr_tmp;
			jump_wrong_tmp  <= (jump_addr_tmp != dnpc);
			pc_next         <= pc[24:0]; //与btb地址位宽一致
			need_btb        <= opcode_type[INST_BEQ] & imm[31] | opcode_type[INST_JAL];
			inst_fencei_tmp <= inst_fencei;
		end
		else begin
			jump_wrong_tmp  <= 0;
			inst_fencei_tmp <= 0;
		end
	end

	assign jump_addr_tmp = csr_jump_en ? csr_jump :
												 jump_en ? exu_jump :
												 snpc;

	assign val = jal_enable ? snpc :
							 csr_enable ? csr_val :
							 alu_val;

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

	wire [31:0] compare;
	wire overflow;
	wire less;
	wire unequal;
	wire uless;

	wire [31:0] op_compare;
	wire [31:0] op_sum;
	wire [31:0] exu_jump;
	wire op_overflow;
	wire op_less;
	wire op_uless;

	wire [31:0] loperand;
	wire [31:0] roperand;
	wire [3:0]  operator;
	wire [3:0]  operator1;
	wire [3:0]  operator2;
	wire [3:0]  operator3;
	wire [62:0] val_sra;
	wire jump_cond;

	//exu_val
	assign loperand = (opcode_type[INST_AUIPC] | opcode_type[INST_JAL] | opcode_type[INST_BEQ]) ? pc : //auipc/jal/beq
										opcode_type[INST_LUI] ? 32'b0 :   //lui
										src1;   //imm/src2/jalr/lw/sw

	assign roperand = opcode_type[INST_ADD] ? src2 :   //src2
										imm;  //lui/auipc/imm/jal/jalr/beq/lw/sw

	localparam OP_ADD   = 4'd0;
	localparam OP_SUB   = 4'd1;
	localparam OP_AND   = 4'd2;
	localparam OP_XOR   = 4'd3;
	localparam OP_OR    = 4'd4;
	localparam OP_SRL   = 4'd5;
	localparam OP_SRA   = 4'd6;
	localparam OP_SLL   = 4'd7;
	localparam OP_LESS  = 4'd8;
	localparam OP_ULESS = 4'd9;
	assign operator = (opcode_type[INST_ADDI] | opcode_type[INST_ADD]) ? operator1 : OP_ADD;

	assign operator1 = (funct3 == 3'b000) ? operator2 :
										 (funct3 == 3'b001) ? OP_SLL : 
										 (funct3 == 3'b010) ? OP_LESS :
										 (funct3 == 3'b011) ? OP_ULESS :
										 (funct3 == 3'b100) ? OP_XOR :
										 (funct3 == 3'b101) ? operator3 :
										 (funct3 == 3'b110) ? OP_OR :
										 (funct3 == 3'b111) ? OP_AND :
										 OP_ADD;

	assign operator2 = (opcode_type[INST_ADD] & funct7_5) ? OP_SUB : OP_ADD;
	assign operator3 = funct7_5 ? OP_SRA : OP_SRL;

	assign {op_overflow, op_compare} = loperand - roperand;
	assign op_sum  = loperand + roperand;
	assign op_less = {(loperand[31] & ~roperand[31]) | ~(loperand[31] ^ roperand[31]) & op_compare[31]};
	assign op_uless = op_overflow;
	assign val_sra = {{31{loperand[31]}}, loperand} >> roperand[4:0];
	assign alu_val = (operator == OP_ADD  ) ? op_sum : 
									 (operator == OP_SUB  ) ? op_compare : 
									 (operator == OP_AND  ) ? (loperand & roperand) : 
									 (operator == OP_XOR  ) ? (loperand ^ roperand) :
									 (operator == OP_OR   ) ? (loperand | roperand) : 
									 (operator == OP_SRL  ) ? (loperand >> roperand[4:0]) : 
									 (operator == OP_SRA  ) ? val_sra[31:0] :
									 (operator == OP_SLL  ) ? (loperand << roperand[4:0]) : 
									 (operator == OP_LESS ) ? {31'b0, op_less} : 
									 (operator == OP_ULESS) ? {31'b0, op_uless} : 
									 32'b0;

	//jump
	assign jump_en = opcode_type[INST_JAL] | opcode_type[INST_JALR] | opcode_type[INST_BEQ] & jump_cond;
	assign exu_jump = op_sum;
	assign {overflow, compare} = src1 - src2;
	assign less = (src1[31] & ~src2[31]) | ~(src1[31] ^ src2[31]) & compare[31];
	assign unequal = |compare;
	assign uless = overflow;

	assign jump_cond = (funct3 == 3'b000) ? ~unequal : 
										 (funct3 == 3'b001) ? unequal : 
										 (funct3 == 3'b100) ? less : 
										 (funct3 == 3'b101) ? ~less :
										 (funct3 == 3'b110) ? uless : 
										 (funct3 == 3'b111) ? ~uless : 
										 1'b0;


	//write
	assign csr_wdata = (funct3 == 3'b010) ? (src1 | csr_val) : 
										 (funct3 == 3'b001) ? src1 :
										 32'b0;

endmodule
module ysyx_23060236_icache(
	input         clock,
	input         reset,

	input  [ADDR_LEN-1:0] icache_araddr,
	output [DATA_LEN-1:0] icache_rdata,
	output        icache_hit,  

	input  [ADDR_LEN-1:0] icache_awaddr,
	input  [DATA_LEN-1:0] icache_wdata,
	input         icache_wvalid,

	input         inst_fencei
);

	//此处ADDR_LEN减7与sdram地址范围相匹配
	localparam ADDR_LEN   = 32 - 7;
	localparam DATA_LEN   = 32;
	localparam OFFSET_LEN = 5;
	localparam INDEX_LEN  = 1;
	localparam TAG_LEN    = ADDR_LEN - OFFSET_LEN - INDEX_LEN;
	localparam BLOCK_SIZE = 2**(OFFSET_LEN-2);

	reg [DATA_LEN-1:0]     icache_data [2**INDEX_LEN-1:0][BLOCK_SIZE-1:0];
	reg [TAG_LEN-1:0]      icache_tag  [2**INDEX_LEN-1:0];
	reg [2**INDEX_LEN-1:0] icache_valid;

	wire [INDEX_LEN-1:0]  read_index;
	wire [TAG_LEN-1:0]    read_tag;
	wire [OFFSET_LEN-3:0] read_offset;
	wire [INDEX_LEN-1:0]  write_index;
	wire [TAG_LEN-1:0]    write_tag;
	wire [OFFSET_LEN-3:0] write_offset;

	assign read_tag     = icache_araddr[ADDR_LEN-1 : OFFSET_LEN+INDEX_LEN];
	assign read_index   = icache_araddr[OFFSET_LEN+INDEX_LEN-1 : OFFSET_LEN];
	assign read_offset  = icache_araddr[OFFSET_LEN-1 : 2];
	assign write_tag    = icache_awaddr[ADDR_LEN-1 : OFFSET_LEN+INDEX_LEN];
	assign write_index  = icache_awaddr[OFFSET_LEN+INDEX_LEN-1 : OFFSET_LEN];
	assign write_offset = icache_awaddr[OFFSET_LEN-1 : 2];
	assign icache_hit   = icache_valid[read_index] & (icache_tag[read_index] == read_tag);
	assign icache_rdata = icache_data[read_index][read_offset[OFFSET_LEN-3:0]];

	always @(posedge clock) begin
		if (reset | inst_fencei) icache_valid <= 0;
		else if (icache_wvalid) icache_valid[write_index] <= 1'b1;
	end

	always @(posedge clock) begin
		if (icache_wvalid) icache_data[write_index][write_offset[OFFSET_LEN-3:0]] <= icache_wdata;
	end

	always @(posedge clock) begin
		if (icache_wvalid) icache_tag[write_index] <= write_tag;
	end

endmodule
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
	output reg inst_fencei,
	output reg inst_ecall,
	output reg inst_mret,

	input  idu_valid,
	output idu_ready,
	output exu_valid,
	input  exu_ready
);

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

	ysyx_23060236_Reg #(1, 0) reg_exu_valid(
		.clock(clock),
		.reset(reset),
		.din((exu_valid & ~exu_ready | idu_valid & idu_ready) & ~jump_wrong),
		.dout(exu_valid),
		.wen(1)
	);

	always @(posedge clock) begin
		if (idu_valid & idu_ready) begin
			opcode_type <= opcode_type_tmp;
			funct3      <= funct3_tmp;
			funct7_5    <= funct7_tmp[5];
			rd          <= rd_tmp;
			imm         <= imm_tmp;
			reg_wen     <= reg_wen_tmp;
			inst_fencei <= inst_fencei_tmp;
			inst_ecall  <= inst_ecall_tmp;
			inst_mret   <= inst_mret_tmp;
			pc_next     <= pc;
			src1_next   <= src1_tmp;
			src2_next   <= src2_tmp;
		end
	end

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
	assign opcode_5       = in[6:2];
	assign rs1            = in[18:15];
	assign rs2            = in[23:20];
	assign rd_tmp         = in[10:7];
	assign funct3_tmp     = in[14:12];
	assign funct7_tmp     = in[31:25];
	assign reg_wen_tmp    = Type[TYPE_I] & ~((funct3_tmp == 3'b0) & opcode_type_tmp[INST_CSR]) | Type[TYPE_U] | Type[TYPE_J] | Type[TYPE_R];

	assign inst_ecall_tmp  = (in == 32'h00000073);
	assign inst_mret_tmp   = (in == 32'h30200073);
	assign inst_fencei_tmp = (opcode_5 == 5'b00011);

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


	import "DPI-C" function void add_raw_conflict();
	import "DPI-C" function void add_raw_conflict_cycle();

	reg raw_conflict_state;
	always @(posedge clock) begin
		if (reset) raw_conflict_state <= 0;
		else raw_conflict_state <= raw_conflict;

		if (raw_conflict) add_raw_conflict_cycle();
		if (~raw_conflict_state & raw_conflict) add_raw_conflict();
	end

endmodule
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

	output [24:0] icache_araddr, //与icache地址位宽一致
	input  [31:0] icache_rdata,
	input         icache_hit,
	output reg [24:0] icache_awaddr, //与icache地址位宽一致
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
	wire pc_in_sdram;
	wire npc_in_sdram;
	wire [31:0] inst_tmp;
	wire [24:0] icache_awaddr_tmp; //与icache地址位宽一致
	reg last;
	wire jump_wrong_state;
	wire [31:0] pc_tmp;

	assign ifu_rready    = 1;
	assign pc_in_sdram   = (pc >= 32'ha0000000) & (pc < 32'ha2000000);
	assign npc_in_sdram  = (pc_tmp >= 32'ha0000000) & (pc_tmp < 32'ha2000000);
	assign icache_araddr = pc[24:0];
	assign ifu_araddr    = ~pc_in_sdram ? pc : {pc[31:5], 5'b0}; //与icache的块大小一致
	assign ifu_arburst   = ~pc_in_sdram ? 2'b0 : 2'b01;
	assign ifu_arlen     = ~pc_in_sdram ? 4'b0 : 4'b0111; //与icache的块大小一致
	//与icache的块大小一致
	assign inst_tmp = (ifu_rvalid & ifu_rready & ((pc[4:2] == icache_awaddr[4:2]) | ~pc_in_sdram)) ? ifu_rdata : 
		                (icache_rvalid & icache_hit & ifu_ready) ? icache_rdata : 
										inst;
	assign ifu_over = (icache_rvalid & icache_hit & ifu_ready | icache_wvalid & last | ifu_rvalid & ifu_rready & ~pc_in_sdram);
	assign ifu_valid = idu_valid & idu_ready | (jump_wrong | jump_wrong_state) & (idu_valid | ifu_over);
	assign ifu_ready = ~idu_valid | idu_ready;
	//与icache的块大小一致
	assign icache_awaddr_tmp = (icache_rvalid & ~icache_hit & ifu_ready) ? {pc[24:5], 5'b0} : 
														 (icache_wvalid & ~last) ? (icache_awaddr + 4) : 
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

	ysyx_23060236_Reg #(32, 32'h30000000) pc_adder(
		.clock(clock),
		.reset(reset),
		.din(pc_tmp),
		.dout(pc),
		.wen(1)
	);

	ysyx_23060236_Reg #(1, 0) reg_icache_rvalid(
		.clock(clock),
		.reset(reset),
		.din(ifu_over & npc_in_sdram | icache_rvalid & ~ifu_ready),
		.dout(icache_rvalid),
		.wen(1)
	);

	ysyx_23060236_Reg #(1, 0) reg_icache_wvalid(
		.clock(clock),
		.reset(reset),
		.din(~icache_wvalid & ifu_rvalid & ifu_rready & pc_in_sdram),
		.dout(icache_wvalid),
		.wen(1)
	);

	always @(posedge clock) begin
		icache_awaddr <= icache_awaddr_tmp;
	end

	ysyx_23060236_Reg #(1, 1) reg_ifu_arvalid(
		.clock(clock),
		.reset(reset),
		.din(ifu_arvalid & ~ifu_arready | ~ifu_arvalid & (icache_rvalid & ~icache_hit & ifu_ready | ifu_valid & ~npc_in_sdram)),
		.dout(ifu_arvalid),
		.wen(1)
	);

	always @(posedge clock) begin
		if (ifu_rvalid & ifu_rready) icache_wdata <= ifu_rdata;
	end

	always @(posedge clock) begin
		inst <= inst_tmp;
	end

	ysyx_23060236_Reg #(1, 0) reg_idu_valid(
		.clock(clock),
		.reset(reset),
		.din(ifu_over & ~jump_wrong & ~jump_wrong_state | idu_valid & ~idu_ready & ~jump_wrong),
		.dout(idu_valid),
		.wen(1)
	);

	ysyx_23060236_Reg #(1, 0) reg_jump_wrong_state(
		.clock(clock),
		.reset(reset),
		.din(jump_wrong_state & ~ifu_over | ~jump_wrong_state & jump_wrong & ~ifu_over & ~idu_valid),
		.dout(jump_wrong_state),
		.wen(1)
	);

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

endmodule
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

	ysyx_23060236_Reg #(1, 1) reg_exu_ready_tmp(
		.clock(clock),
		.reset(reset),
		.din(exu_ready_tmp & ~(exu_ready & exu_valid) | lsu_over),
		.dout(exu_ready_tmp),
		.wen(1)
	);

	ysyx_23060236_Reg #(1, 0) reg_wb_valid(
		.clock(clock),
		.reset(reset),
		.din(lsu_over),
		.dout(wb_valid),
		.wen(1)
	);

	wire [31:0] lsu_val_tmp;
	wire [31:0] lsu_val_shift;

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

	ysyx_23060236_Reg #(1, 0) reg_lsu_arvalid(
		.clock(clock),
		.reset(reset),
		.din(lsu_arvalid & ~lsu_arready | ~lsu_arvalid & lsu_ren & exu_valid & exu_ready),
		.dout(lsu_arvalid),
		.wen(1)
	);

	ysyx_23060236_Reg #(1, 0) reg_lsu_awvalid(
		.clock(clock),
		.reset(reset),
		.din(lsu_awvalid & ~lsu_awready | ~lsu_awvalid & lsu_wen & exu_valid & exu_ready),
		.dout(lsu_awvalid),
		.wen(1)
	);

	ysyx_23060236_Reg #(1, 0) reg_lsu_wvalid(
		.clock(clock),
		.reset(reset),
		.din(lsu_wvalid & ~lsu_wready | ~lsu_wvalid & lsu_wen & exu_valid & exu_ready),
		.dout(lsu_wvalid),
		.wen(1)
	);

endmodule
module ysyx_23060236_RegisterFile #(ADDR_WIDTH = 4, DATA_WIDTH = 32) (
  input clock,
  input [DATA_WIDTH-1:0] wdata,
  input [ADDR_WIDTH-1:0] waddr,
	output [DATA_WIDTH-1:0] rdata1,
	input [ADDR_WIDTH-1:0] raddr1,
	output [DATA_WIDTH-1:0] rdata2,
	input [ADDR_WIDTH-1:0] raddr2,
  input wen,
	input valid
);

  reg [DATA_WIDTH-1:0] rf [2**ADDR_WIDTH-1:1];

  always @(posedge clock) begin
		if (valid & wen & (waddr != 0)) begin
			rf[waddr] <= wdata;
		end
  end

	assign rdata1 = (raddr1 == 0) ? 0 : rf[raddr1];
	assign rdata2 = (raddr2 == 0) ? 0 : rf[raddr2];

endmodule
module ysyx_23060236_Reg #(WIDTH = 1, RESET_VAL = 0) (
  input clock,
  input reset,
  input [WIDTH-1:0] din,
  output reg [WIDTH-1:0] dout,
  input wen
);
  always @(posedge clock) begin
    if (reset) dout <= RESET_VAL;
    else if (wen) dout <= din;
  end
endmodule
module ysyx_23060236(
	input  clock,
	input  reset,
	input  io_interrupt,

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
	wire [24:0] exu_pc; //与btb地址位宽一致
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

	wire [24:0] icache_araddr; //与icache地址位宽一致
	wire [31:0] icache_rdata;
	wire        icache_hit;
	wire [24:0] icache_awaddr; //与icache地址位宽一致
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

	ysyx_23060236_btb my_btb(
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
		.inst_fencei(inst_fencei),
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

endmodule
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

	ysyx_23060236_Reg #(1, 0) state_ifu_reading(
		.clock(clock),
		.reset(reset),
		.din(~ifu_reading & ~lsu_arvalid & ~lsu_reading & ifu_arvalid | ifu_reading & ~(ifu_rvalid & ifu_rready & ifu_rlast)),
		.dout(ifu_reading),
		.wen(1)
	);

	ysyx_23060236_Reg #(1, 0) state_lsu_reading(
		.clock(clock),
		.reset(reset),
		.din(~lsu_reading & ~ifu_reading & lsu_arvalid | lsu_reading & ~(lsu_rvalid & lsu_rready)),
		.dout(lsu_reading),
		.wen(1)
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

endmodule
