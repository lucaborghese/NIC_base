`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_va_vn_N_to_1 
// Project Name:	NIC_base
// Description:	testbench module va_vn_N_to_1
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "va_vn_N_to_1.v"

module testbench_va_vn_N_to_1
	#(
	parameter	N_OF_REQUEST		=	`N_FIFO_OUT_BUFFER,
	parameter	N_OF_VC				=	`N_OF_VC,
	parameter	N_BITS_OF_REQUEST	=	clog2(N_OF_REQUEST)
	)
	();

	`include "NIC_utils.vh"

	reg clk;
	reg rst;

	always #5 clk=~clk;

	reg	[N_OF_VC-1:0]					vc_free_i;
	reg	[N_OF_REQUEST-1:0]			r_va_vn_i;
	wire	[N_OF_REQUEST-1:0]			g_va_vn_o;
	wire	[N_OF_REQUEST*N_OF_VC-1:0]	g_vc_o;

	va_vn_N_to_1
		#(
		.N_OF_REQUEST(N_OF_REQUEST),
		.N_OF_VC(N_OF_VC),
		.N_BITS_OF_REQUEST(N_BITS_OF_REQUEST)
		)
		va_vn
		(
		.clk(clk),
		.rst(rst),

		.vc_free_i(vc_free_i),
		.r_va_vn_i(r_va_vn_i),
		.g_va_vn_o(g_va_vn_o),
		.g_vc_o(g_vc_o)
		);

	initial begin
		clk = 0;
		rst = 1;
		vc_free_i = 0;
		r_va_vn_i = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		repeat(10) begin
			vc_free_i = $random;
			r_va_vn_i = $random;
			@(posedge clk);
		end//repeat
		$finish;
	end//initial

endmodule//testbench_va_vn_N_to_1
