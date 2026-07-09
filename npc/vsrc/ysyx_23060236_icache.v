`include "ysyx_23060236_defines.v"
module ysyx_23060236_icache(
	clock,
	reset,

	icache_araddr,
	icache_rdata,
	icache_hit,  

	icache_awaddr,
	icache_wdata,
	icache_wvalid,

	inst_fencei
);

	// 此处ADDR_LEN减7与sdram地址范围相匹配(已去除)
	localparam ADDR_LEN   = 32;
	localparam DATA_LEN   = 32;
	localparam OFFSET_LEN = 5;
	localparam INDEX_LEN  = 1;
	localparam TAG_LEN    = ADDR_LEN - OFFSET_LEN - INDEX_LEN;
	localparam BLOCK_SIZE = 2**(OFFSET_LEN-2);

	input         clock;
	input         reset;

	input  [ADDR_LEN-1:0] icache_araddr;
	output [DATA_LEN-1:0] icache_rdata;
	output        icache_hit;  

	input  [ADDR_LEN-1:0] icache_awaddr;
	input  [DATA_LEN-1:0] icache_wdata;
	input         icache_wvalid;

	input         inst_fencei;

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
