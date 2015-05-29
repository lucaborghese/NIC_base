`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_fifo_nic2noc 
// Project Name:	NIC_base
// Description:	Testbench for fifo_nic2noc module
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "fifo_nic2noc.v"

module testbench_fifo_nic2noc
	#(
	parameter	N_TOT_OF_VC		=	`N_OF_VC*`N_OF_VN,
	parameter	N_BITS_POINTER	=	clog2(`N_FIFO_OUT_BUFFER)
	)
	();

	`include "NIC_utils.vh"

	reg	clk;
	reg	rst;

	//clock
	always #5 clk=~clk;

	//NoC side
	reg	[N_TOT_OF_VC-1:0]	credit_signal_i;
	reg	[N_TOT_OF_VC-1:0]	free_signal_i;
	wire	[`FLIT_WIDTH-1:0]	out_link_o;
	wire							is_valid_o;

	//wb_slave_interface side
	reg	[N_TOT_OF_VC-1:0]						g_fifo_pointer_i;
	reg	[N_TOT_OF_VC*N_BITS_POINTER-1:0]	g_fifo_out_buffer_id_i;
	reg	[N_TOT_OF_VC-1:0]						release_pointer_i;
	wire	[N_TOT_OF_VC-1:0]						credit_signal_o;
	wire	[N_TOT_OF_VC*N_BITS_POINTER-1:0]	fifo_pointed_o;
	reg	[`FLIT_WIDTH-1:0]						in_link_i;
	reg												is_valid_i;

	//VA side
	wire	[N_TOT_OF_VC-1:0]		free_signal_o;
	wire	[N_TOT_OF_VC-1:0]		fifo_pointer_state_o;

	fifo_nic2noc
		#(
		.N_TOT_OF_VC(N_TOT_OF_VC),
		.N_BITS_POINTER(N_BITS_POINTER)
		)
		fifo_pointers
		(
		.clk(clk),
		.rst(rst),

		//NoC side
		.credit_signal_i(credit_signal_i),
		.free_signal_i(free_signal_i),
		.out_link_o(out_link_o),
		.is_valid_o(is_valid_o),
		//wb_slave_interface_side
		.g_fifo_pointer_i(g_fifo_pointer_i),
		.g_fifo_out_buffer_id_i(g_fifo_out_buffer_id_i),
		.release_pointer_i(release_pointer_i),
		.credit_signal_o(credit_signal_o),
		.fifo_pointed_o(fifo_pointed_o),
		.in_link_i(in_link_i),
		.is_valid_i(is_valid_i),
		//vc_allocator side
		.free_signal_o(free_signal_o),
		.fifo_pointer_state_o(fifo_pointer_state_o)
		);

	initial begin
		in_link_i = 0;
		is_valid_i = 0;
		credit_signal_i = 0;
		free_signal_i = 0;
		clk = 0;
		rst = 1;
		g_fifo_pointer_i = 0;
		g_fifo_out_buffer_id_i = 0;
		release_pointer_i = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		g_fifo_pointer_i = 6'b001010;
		g_fifo_out_buffer_id_i = 18'b000000010000011001;
		@(posedge clk);
		g_fifo_pointer_i = 6'b000001;
		@(posedge clk);
		g_fifo_pointer_i = 0;
		release_pointer_i = 6'b001001;
		@(posedge clk);
		release_pointer_i = 0;
		@(posedge clk);
		g_fifo_pointer_i = 6'b000001;
		release_pointer_i = 6'b000010;
		@(posedge clk);
		release_pointer_i = 0;
		g_fifo_pointer_i = 0;
		@(posedge clk);
		$finish;
	end//initial

endmodule//testbench_fifo_nic2noc
