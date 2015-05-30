`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_vc_allocator 
// Project Name:	NIC_base
// Description: 
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "vc_allocator.v"

module testbench_vc_allocator
	#(
	parameter	N_OF_REQUEST			=	3,//`N_FIFO_OUT_BUFFER
	parameter	N_BITS_N_OF_REQUEST	=	clog2(N_OF_REQUEST),
	parameter	N_OF_VN					=	2,//`N_OF_VN
	parameter	N_OF_VC					=	2,//`N_OF_VC
	parameter	N_TOT_OF_VC				=	N_OF_VN*N_OF_VC
	)
	();

	`include "NIC_utils.vh"

	//clock
	reg	clk;
	reg	rst;

	always #5 clk=~clk;

	//input
	reg	[N_OF_REQUEST-1:0]					r_va_i;
	reg	[N_OF_REQUEST*N_TOT_OF_VC-1:0]	r_vc_requested_i;
	wire	[N_OF_REQUEST-1:0]					g_va_o;
	wire	[N_OF_REQUEST*N_TOT_OF_VC-1:0]	g_vc_id_o;

	//state of the fifo pointer(one for vc*vn)
	reg	[N_TOT_OF_VC-1:0]					fifo_pointer_state_i;

	vc_allocator
		#(
		.N_OF_REQUEST(N_OF_REQUEST),
		.N_BITS_N_OF_REQUEST(N_BITS_N_OF_REQUEST),
		.N_OF_VN(N_OF_VN),
		.N_OF_VC(N_OF_VC),
		.N_TOT_OF_VC(N_TOT_OF_VC)
		)
		va
		(
		.clk(clk),
		.rst(rst),

		.r_va_i(r_va_i),
		.r_vc_requested_i(r_vc_requested_i),
		.g_va_o(g_va_o),
		.g_vc_id_o(g_vc_id_o),
		.fifo_pointer_state_i(fifo_pointer_state_i)
		);

	initial begin
		clk = 0;
		rst = 1;
		r_va_i = 0;
		r_vc_requested_i = 0;
		fifo_pointer_state_i = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		fifo_pointer_state_i = 4'b1010;
		r_va_i = 3'b101;
		r_vc_requested_i = 12'b110000001100;
		@(posedge clk);
		fifo_pointer_state_i = 4'b0000;
		r_va_i = 3'b111;
		r_vc_requested_i = 12'b110000111100;
		@(posedge clk);
		fifo_pointer_state_i = 4'b0101;
		r_va_i = 3'b111;
		r_vc_requested_i = 12'b001100111100;
		@(posedge clk);
		$finish;
	end//initial

endmodule//testbench_vc_allocator
