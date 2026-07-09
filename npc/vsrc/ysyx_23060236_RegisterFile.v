`include "ysyx_23060236_defines.v"
module ysyx_23060236_RegisterFile(
   clock,
`ifdef __ICARUS__
	 return_value,
`endif
   wdata,
   waddr,
	 rdata1,
	 raddr1,
	 rdata2,
	 raddr2,
   wen,
	 valid
);
	parameter ADDR_WIDTH = 4;
	parameter DATA_WIDTH = 32;

  input clock;
`ifdef __ICARUS__
	output [DATA_WIDTH-1:0] return_value;
`endif
  input [DATA_WIDTH-1:0] wdata;
  input [ADDR_WIDTH-1:0] waddr;
	output [DATA_WIDTH-1:0] rdata1;
	input [ADDR_WIDTH-1:0] raddr1;
	output [DATA_WIDTH-1:0] rdata2;
	input [ADDR_WIDTH-1:0] raddr2;
  input wen;
	input valid;

  reg [DATA_WIDTH-1:0] rf [2**ADDR_WIDTH-1:1];

  always @(posedge clock) begin
		if (valid & wen & (waddr != 0)) begin
			rf[waddr] <= wdata;
		end
  end

	assign rdata1 = (raddr1 == 0) ? 0 : rf[raddr1];
	assign rdata2 = (raddr2 == 0) ? 0 : rf[raddr2];
`ifdef __ICARUS__
	assign return_value = rf[10];
`endif

endmodule
