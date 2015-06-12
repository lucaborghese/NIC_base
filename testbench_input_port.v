`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  
// Module Name:	testbench_input_port 
// Project Name:	NIC_base
// Description:	Testbench for input_port module
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"

module testbench_input_port
	#(
	parameter N_TOT_OF_VC						=	`N_OF_VC*`N_OF_VN,
	parameter N_BITS_POINTER_FLITS_BUFFER	=	clog2(`MAX_PACKET_LENGHT),
	parameter N_BITS_POINTER					=	clog2(N_TOT_OF_VC)
	)
	();

	`include "NIC_utils.vh"

	reg clk;
	reg rst;

	always #5 clk=~clk;

	//Router side
	reg	[`FLIT_WIDTH-1:0]	in_link_i;
	reg							is_valid_i;
	wire	[N_TOT_OF_VC-1:0]	credit_signal_o;
	wire	[N_TOT_OF_VC-1:0]	free_signal_o;

	//queue side
	reg														g_pkt_to_msg_i;
	wire														r_pkt_to_msg_o;
	wire	[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	out_link_o;

	input_port
		#(
		.N_TOT_OF_VC(N_TOT_OF_VC),
		.N_BITS_POINTER_FLITS_BUFFER(N_BITS_POINTER_FLITS_BUFFER),
		.N_BITS_POINTER(N_BITS_POINTER)
		)
		input_port
		(
		.clk(clk),
		.rst(rst),

		//Router side
		.in_link_i(in_link_i),
		.is_valid_i(is_valid_i),
		.credit_signal_o(credit_signal_o),
		.free_signal_o(free_signal_o),
		//queue side
		.g_pkt_to_msg_i(g_pkt_to_msg_i),
		.r_pkt_to_msg_o(r_pkt_to_msg_o),
		.out_link_o(out_link_o)
		);

	initial begin
		clk = 0;
		rst = 1;
		in_link_i = 0;
		is_valid_i = 0;
		g_pkt_to_msg_i = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		is_valid_i = 1;
		in_link_i = 16'h0004;//vn 1 vc 0
		@(posedge clk);
		in_link_i = 16'hBBB5;
		@(posedge clk);
		in_link_i = 16'hCCC5;
		@(posedge clk);
		in_link_i = 16'hDDD5;
		@(posedge clk);
		in_link_i = 16'hFFF6;
		@(posedge clk);
		in_link_i = 16'h0003;//vn 0 vc 0
		@(posedge clk);
		in_link_i = 16'hAAAF;//vn 1 vc 1
		@(posedge clk);
		is_valid_i = 0;
		g_pkt_to_msg_i = 1;
		@(posedge clk);
		g_pkt_to_msg_i = 0;
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		g_pkt_to_msg_i = 1;
		@(posedge clk);
		g_pkt_to_msg_i = 0;
		@(posedge clk);
		@(posedge clk);
		g_pkt_to_msg_i = 1;
		@(posedge clk);
		g_pkt_to_msg_i = 0;
		@(posedge clk);
		$finish;
	end//initial

endmodule//testbench_input_port
