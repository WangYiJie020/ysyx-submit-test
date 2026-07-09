//`define WAVE_TRACE
`ifndef __ICARUS__
import "DPI-C" function int pmem_read(input int raddr);
import "DPI-C" function void pmem_write(
	  input int waddr, input int wdata, input byte wmask);
`endif

`ifdef __ICARUS__
`timescale 1ns / 1ps
module iverilog_tb;

reg clock;
reg reset;
`ifndef NETLIST
wire sim_end;
wire [31:0] return_value;
`endif

initial begin
	clock = 0;
	forever #5 clock = ~clock;
end

initial begin
	reset = 1;
	#20;
	reset = 0;
`ifdef WAVE_TRACE
	$dumpfile("iverilog_wave.fst");
	$dumpvars(0, iverilog_tb);
`endif
	$display("Start simulation");
`ifndef NETLIST
	wait(sim_end == 1);
	$display("Simulation ended at time %0t ns", $time);
	if (return_value == 0) begin
		$display("HIT GOOD TRAP");
		$finish;
	end
	else begin
		$display("HIT BAD TRAP");
		$fatal;
	end
`endif
end

npc my_npc(
	.clock(clock),
	.reset(reset),
`ifndef NETLIST
	.return_value(return_value),
	.sim_end(sim_end),
`endif
  .externalPins_gpio_out(),	
  .externalPins_gpio_in(),	
  .externalPins_gpio_seg_0(),	
  .externalPins_gpio_seg_1(),	
  .externalPins_gpio_seg_2(),	
  .externalPins_gpio_seg_3(),	
  .externalPins_gpio_seg_4(),	
  .externalPins_gpio_seg_5(),	
  .externalPins_gpio_seg_6(),	
  .externalPins_gpio_seg_7(),	
  .externalPins_ps2_clk(),	
  .externalPins_ps2_data(),	
  .externalPins_vga_r(),	
  .externalPins_vga_g(),	
  .externalPins_vga_b(),	
  .externalPins_vga_hsync(),	
  .externalPins_vga_vsync(),	
  .externalPins_vga_valid(),	
  .externalPins_uart_rx(),	
  .externalPins_uart_tx()
);

endmodule
`endif

module npc(
	input  clock,
	input  reset,
`ifdef __ICARUS__
`ifndef NETLIST
	output sim_end,
	output [31:0] return_value,
`endif
`endif

  output [15:0] externalPins_gpio_out,	
  input  [15:0] externalPins_gpio_in,	
  output [7:0]  externalPins_gpio_seg_0,	
                externalPins_gpio_seg_1,	
                externalPins_gpio_seg_2,	
                externalPins_gpio_seg_3,	
                externalPins_gpio_seg_4,	
                externalPins_gpio_seg_5,	
                externalPins_gpio_seg_6,	
                externalPins_gpio_seg_7,	
  input         externalPins_ps2_clk,	
                externalPins_ps2_data,	
  output [7:0]  externalPins_vga_r,	
                externalPins_vga_g,	
                externalPins_vga_b,	
  output        externalPins_vga_hsync,	
                externalPins_vga_vsync,	
                externalPins_vga_valid,	
  input         externalPins_uart_rx,	
  output        externalPins_uart_tx	
);

reg         io_master_awready;
wire        io_master_awvalid;
wire [31:0] io_master_awaddr;
wire [3:0]  io_master_awid;
wire [7:0]  io_master_awlen;
wire [2:0]  io_master_awsize;
wire [1:0]  io_master_awburst;

reg         io_master_wready;
wire        io_master_wvalid;
wire [31:0] io_master_wdata;
wire [3:0]  io_master_wstrb;
wire        io_master_wlast;

wire        io_master_bready;
reg         io_master_bvalid;
wire [1:0]  io_master_bresp;
wire [3:0]  io_master_bid;

reg         io_master_arready;
wire        io_master_arvalid;
wire [31:0] io_master_araddr;
wire [3:0]  io_master_arid;
wire [7:0]  io_master_arlen;
wire [2:0]  io_master_arsize;
wire [1:0]  io_master_arburst;

wire        io_master_rready;
reg         io_master_rvalid;
wire [1:0]  io_master_rresp;
reg  [31:0] io_master_rdata;
wire        io_master_rlast;
wire [3:0]  io_master_rid;

`ifdef __ICARUS__
parameter MEM_SIZE = 2**27;
reg  [7:0] memory [MEM_SIZE];
integer i;
initial begin
	$readmemh(`MEM_FILE, memory);
end
`endif

// write
reg  [31:0] write_addr;

assign io_master_bid = 0;
assign io_master_bresp = 0;
assign io_master_wlast = 1;

always @(posedge clock) begin
// io_master_awready
	if (reset) io_master_awready <= 1;
	else if (io_master_awready & io_master_awvalid) 
		io_master_awready <= 0;
	else if (io_master_bvalid & io_master_bready)
		io_master_awready <= 1;

// write_addr
	if (io_master_awready & io_master_awvalid)
		write_addr <= io_master_awaddr;

// io_master_wready
	if (reset) io_master_wready <= 0;
	else if (io_master_wvalid & io_master_wready)
		io_master_wready <= 0;
	else if (io_master_awvalid & io_master_awready)
		io_master_wready <= 1;

// pmem_write & write_wstrb
`ifndef __ICARUS__
	if (io_master_wvalid & io_master_wready) begin
		pmem_write(write_addr, io_master_wdata, {4'b0, io_master_wstrb});
	end
`else
	if (io_master_wvalid & io_master_wready) begin
		if (write_addr == 32'ha00003f8) begin
			$write("%c", io_master_wdata[7:0]);
			$fflush();
		end
		else begin
			if (io_master_wstrb[0]) memory[{write_addr[26:2],2'b0}  ] <= io_master_wdata[7 :0 ];
			if (io_master_wstrb[1]) memory[{write_addr[26:2],2'b0}+1] <= io_master_wdata[15:8 ];
			if (io_master_wstrb[2]) memory[{write_addr[26:2],2'b0}+2] <= io_master_wdata[23:16];
			if (io_master_wstrb[3]) memory[{write_addr[26:2],2'b0}+3] <= io_master_wdata[31:24];
		end
	end
`endif

// io_master_bvalid
	if (reset) io_master_bvalid <= 0;
	else if (io_master_bvalid & io_master_bready)
		io_master_bvalid <= 0;
	else if (io_master_wvalid & io_master_wready)
		io_master_bvalid <= 1;
end


//read
reg  [31:0] read_addr;
reg  [7:0]  read_len;

assign io_master_rid = 0;
assign io_master_rresp = 0;
assign io_master_rlast = (read_len == 0);

always @(posedge clock) begin
// io_master_arready
	if (reset) io_master_arready <= 1;
	else if (io_master_arready & io_master_arvalid)
		io_master_arready <= 0;
	else if (io_master_rready & io_master_rvalid & (read_len == 0))
		io_master_arready <= 1;

// read_addr
	if (io_master_arready & io_master_arvalid)
		read_addr <= io_master_araddr + 4;
	else if (io_master_rready & io_master_rvalid)
		read_addr <= read_addr + 4;

// read_len
	if (io_master_arready & io_master_arvalid)
		if (io_master_arburst == 2'b01)
			read_len <= io_master_arlen;
		else read_len <= 0;
	else if (io_master_rvalid & io_master_rready & (read_len != 0))
		read_len <= read_len - 1;

// io_master_rvalid
	if (reset) io_master_rvalid <= 0;
	else if (io_master_rvalid & io_master_rready)
		if (read_len != 0) io_master_rvalid <= 1;
		else io_master_rvalid <= 0;
	else if (io_master_arvalid & io_master_arready)
		io_master_rvalid <= 1;

// io_master_rdata
`ifndef __ICARUS__
	if (io_master_arvalid & io_master_arready)
		io_master_rdata <= pmem_read(io_master_araddr);
	else if (io_master_rvalid & io_master_rready & (read_len != 0))
		io_master_rdata <= pmem_read(read_addr);
`else
	if (io_master_arvalid & io_master_arready) begin
		io_master_rdata[7 :0 ] <= memory[{io_master_araddr[26:2],2'b0}  ];
		io_master_rdata[15:8 ] <= memory[{io_master_araddr[26:2],2'b0}+1];
		io_master_rdata[23:16] <= memory[{io_master_araddr[26:2],2'b0}+2];
		io_master_rdata[31:24] <= memory[{io_master_araddr[26:2],2'b0}+3];
	end
	else if (io_master_rvalid & io_master_rready & (read_len != 0)) begin
		io_master_rdata[7 :0 ] <= memory[{read_addr[26:2],2'b0}  ];
		io_master_rdata[15:8 ] <= memory[{read_addr[26:2],2'b0}+1];
		io_master_rdata[23:16] <= memory[{read_addr[26:2],2'b0}+2];
		io_master_rdata[31:24] <= memory[{read_addr[26:2],2'b0}+3];
	end
`endif
end

  ysyx_23060236 cpu (	
    .clock             (clock),
    .reset             (reset),
    .io_interrupt      (1'h0),
`ifdef __ICARUS__
`ifndef NETLIST
		.sim_end(sim_end),
		.return_value(return_value),
`endif
`endif
    .io_master_awready (io_master_awready),
    .io_master_awvalid (io_master_awvalid),
    .io_master_awid    (io_master_awid),
    .io_master_awaddr  (io_master_awaddr),
    .io_master_awlen   (io_master_awlen),
    .io_master_awsize  (io_master_awsize),
    .io_master_awburst (io_master_awburst),
    .io_master_wready  (io_master_wready),
    .io_master_wvalid  (io_master_wvalid),
    .io_master_wdata   (io_master_wdata),
    .io_master_wstrb   (io_master_wstrb),
    .io_master_wlast   (io_master_wlast),
    .io_master_bready  (io_master_bready),
    .io_master_bvalid  (io_master_bvalid),
    .io_master_bid     (io_master_bid),
    .io_master_bresp   (io_master_bresp),
    .io_master_arready (io_master_arready),
    .io_master_arvalid (io_master_arvalid),
    .io_master_arid    (io_master_arid),
    .io_master_araddr  (io_master_araddr),
    .io_master_arlen   (io_master_arlen),
    .io_master_arsize  (io_master_arsize),
    .io_master_arburst (io_master_arburst),
    .io_master_rready  (io_master_rready),
    .io_master_rvalid  (io_master_rvalid),
    .io_master_rid     (io_master_rid),
    .io_master_rdata   (io_master_rdata),
    .io_master_rresp   (io_master_rresp),
    .io_master_rlast   (io_master_rlast),
    .io_slave_awready  (/* unused */),
    .io_slave_awvalid  (1'h0),	
    .io_slave_awid     (4'h0),	
    .io_slave_awaddr   (32'h0),	
    .io_slave_awlen    (8'h0),	
    .io_slave_awsize   (3'h0),	
    .io_slave_awburst  (2'h0),	
    .io_slave_wready   (/* unused */),
    .io_slave_wvalid   (1'h0),	
    .io_slave_wdata    (32'h0),	
    .io_slave_wstrb    (4'h0),	
    .io_slave_wlast    (1'h0),	
    .io_slave_bready   (1'h0),	
    .io_slave_bvalid   (/* unused */),
    .io_slave_bid      (/* unused */),
    .io_slave_bresp    (/* unused */),
    .io_slave_arready  (/* unused */),
    .io_slave_arvalid  (1'h0),	
    .io_slave_arid     (4'h0),	
    .io_slave_araddr   (32'h0),	
    .io_slave_arlen    (8'h0),	
    .io_slave_arsize   (3'h0),	
    .io_slave_arburst  (2'h0),	
    .io_slave_rready   (1'h0),	
    .io_slave_rvalid   (/* unused */),
    .io_slave_rid      (/* unused */),
    .io_slave_rdata    (/* unused */),
    .io_slave_rresp    (/* unused */),
    .io_slave_rlast    (/* unused */)
	);

endmodule
