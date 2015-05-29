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
	parameter	N_OF_REQUEST	=	3,
	parameter	N_BITS_VNET_ID	=	clog2(`N_OF_VN),
	parameter	N_BITS_VC_ID	=	`N_OF_VC*`N_OF_VN
	)
	();

	`include "NIC_utils.vh"

	//clock
	reg	clk;
	
	always #5 clk=~clk;

	//input
	reg	[N_OF_REQUEST-1:0]						r_va_i;
	reg	[N_OF_REQUEST*N_BITS_VNET_ID-1:0]	vnet_of_the_request_i;
	wire	[N_OF_REQUEST-1:0]						g_va_o;
	wire	[N_OF_REQUEST*N_BITS_VC_ID-1:0]		g_vc_id_o;//one-hot encoding for every request

	//vc state of the router from free_signal
	reg	[`N_OF_VC*`N_OF_VN-1:0]					free_signal_i;//signal from the router

	//state of the fifo pointer(one for vc*vn)
	reg	[`N_OF_VC*`N_OF_VN-1:0]					fifo_pointer_state_i;

	vc_allocator
		#(
		.N_OF_REQUEST(N_OF_REQUEST),
		.N_BITS_VNET_ID(N_BITS_VNET_ID),
		.N_BITS_VC_ID(N_BITS_VC_ID)
		)
		va
		(
		.r_va_i(r_va_i),
		.vnet_of_the_request_i(vnet_of_the_request_i),
		.free_signal_i(free_signal_i),
		.fifo_pointer_state_i(fifo_pointer_state_i),
		.g_va_o(g_va_o),
		.g_vc_id_o(g_vc_id_o)
		);

	initial begin
		clk = 1;
		r_va_i = 3'b101;
		vnet_of_the_request_i = 6'b100101;
		free_signal_i = 6'b011111;
		fifo_pointer_state_i = 6'b101101;
		@(posedge clk);
		$finish;
	end//initial

endmodule//testbench_vc_allocator
