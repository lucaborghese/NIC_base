`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_link_allocator 
// Project Name:	NIC_base
// Description:	Testbench for link_allocator module
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "link_allocator.v"

module testbench_link_allocator
	#(
	parameter N_REQUEST_SIGNAL		=	6,
	parameter N_BITS_POINTER		=	clog2(N_REQUEST_SIGNAL)
	)
	();

	`include "NIC_utils.vh"

	reg	clk;
	reg	rst;

	//clock
	always #5 clk = ~clk;

	//fifo side
	reg	[N_REQUEST_SIGNAL-1:0]	r_la_i;
	wire									g_la_o;
	wire	[N_BITS_POINTER-1:0]		g_channel_id_o;

	link_allocator
		#(
		.N_REQUEST_SIGNAL(N_REQUEST_SIGNAL),
		.N_BITS_POINTER(N_BITS_POINTER)
		)
		la
		(
		.clk(clk),
		.rst(rst),

		//input fifo side
		.r_la_i(r_la_i),
		//output fifo side
		.g_la_o(g_la_o),
		.g_channel_id_o(g_channel_id_o)
		);

	initial begin
		clk = 0;
		rst = 1;
		r_la_i = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		r_la_i = $random;
		@(posedge clk);
		r_la_i = $random;
		@(posedge clk);
		r_la_i = $random;
		@(posedge clk);
		r_la_i = $random;
		@(posedge clk);
		r_la_i = $random;
		@(posedge clk);
		r_la_i = $random;
		@(posedge clk);
		r_la_i = 0;
		@(posedge clk);
		r_la_i = $random;
		@(posedge clk);
		r_la_i = $random;
		@(posedge clk);
		r_la_i = $random;
		@(posedge clk);
		@(posedge clk);
		$finish;
	end//initial

endmodule//testbench_link_allocator
