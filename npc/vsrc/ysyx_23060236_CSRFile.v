`include "ysyx_23060236_defines.v"
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

