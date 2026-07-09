`include "ysyx_23060236_defines.v"
module ysyx_23060236_Reg(
  clock,
  reset,
  din,
  dout,
  wen
);
	parameter WIDTH = 1;
	parameter RESET_VAL = 0;

  input clock;
  input reset;
  input [WIDTH-1:0] din;
  output reg [WIDTH-1:0] dout;
  input wen;

  always @(posedge clock) begin
    if (reset) dout <= RESET_VAL;
    else if (wen) dout <= din;
  end
endmodule
