`include "ysyx_23060236_defines.v"
module ysyx_23060236_btb(
	clock,
	reset,

	btb_araddr,
	btb_rdata,
	btb_araddr_exu,
	btb_rdata_exu,

	btb_wvalid,
	btb_awaddr,
	btb_wdata
);

	localparam ADDR_LEN   = 32 - 16;
	localparam DATA_LEN   = 32;
	localparam OFFSET_LEN = 2;
	localparam INDEX_LEN  = 0;
	localparam TAG_LEN    = ADDR_LEN - OFFSET_LEN - INDEX_LEN;

	input clock;
	input reset;

	input  [DATA_LEN-1:0] btb_araddr;
	output [DATA_LEN-1:0] btb_rdata;
	input  [DATA_LEN-1:0] btb_araddr_exu;
	output [DATA_LEN-1:0] btb_rdata_exu;

	input  btb_wvalid;
	input  [ADDR_LEN-1:0] btb_awaddr;
	input  [DATA_LEN-1:0] btb_wdata;

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

module ysyx_23060236_btb_blank(
	clock,
	reset,

	btb_araddr,
	btb_rdata,
	btb_araddr_exu,
	btb_rdata_exu,

	btb_wvalid,
	btb_awaddr,
	btb_wdata
);

	localparam ADDR_LEN   = 32 - 16;
	localparam DATA_LEN   = 32;
	localparam OFFSET_LEN = 2;
	localparam INDEX_LEN  = 0;
	localparam TAG_LEN    = ADDR_LEN - OFFSET_LEN - INDEX_LEN;

	input clock;
	input reset;

	input  [DATA_LEN-1:0] btb_araddr;
	output [DATA_LEN-1:0] btb_rdata;
	input  [DATA_LEN-1:0] btb_araddr_exu;
	output [DATA_LEN-1:0] btb_rdata_exu;

	input  btb_wvalid;
	input  [ADDR_LEN-1:0] btb_awaddr;
	input  [DATA_LEN-1:0] btb_wdata;

	assign btb_rdata     = btb_araddr + 4;
	assign btb_rdata_exu = btb_araddr_exu + 4;

endmodule
