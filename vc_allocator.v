//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	vc_allocator 
// Project Name:	NIC_base
// Description:	Virtual channel allocator, it receive the state of the router
//						buffer and assign the virtual channel to a packet
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"

module vc_allocator
	#(
	parameter	N_OF_REQUEST	=	3,
	parameter	N_BITS_VNET_ID	=	2,
	parameter	N_BITS_VC_ID	=	6
	)
	(
//	input	clk,
//	input	rst,

	//request
	input				[N_OF_REQUEST-1:0]						r_va_i,
	input				[N_OF_REQUEST*N_BITS_VNET_ID-1:0]	vnet_of_the_request_i,
	output	reg	[N_OF_REQUEST-1:0]						g_va_o,
	output	reg	[N_OF_REQUEST*N_BITS_VC_ID-1:0]		g_vc_id_o,//one-hot encoding for every request

	//vc state of the router from free_signal
	input				[`N_OF_VC*`N_OF_VN-1:0]					free_signal_i,//signal from the router

	//state of the fifo pointer(one for vc*vn)
	input				[`N_OF_VC*`N_OF_VN-1:0]					fifo_pointer_state_i//signal from the fifo_nic2noc module, if high the i-th bit means that the i-th vc is busy
	);

	genvar i;

	wire	[N_BITS_VNET_ID-1:0]	vnet_of_the_request[N_OF_REQUEST-1:0];
	generate
		for( i=0 ; i<N_OF_REQUEST ; i=i+1 ) begin : extraction_of_vnet_of_the_request
			assign vnet_of_the_request[i] = vnet_of_the_request_i[(i+1)*N_BITS_VNET_ID-1:i*N_BITS_VNET_ID];
		end//for
	endgenerate

	//if high the i-th bit of this signal, in this cycle the i-th vc can be allocated to someone
	reg	[`N_OF_VC*`N_OF_VN-1:0]	vc_free;
	
	integer k0;
	integer k1;
	reg	[N_BITS_VNET_ID-1:0]	vnet;
	always @(*) begin
		vnet = 0;
		vc_free = (~fifo_pointer_state_i) & free_signal_i;
		g_va_o = 0;
		g_vc_id_o = 0;
		for( k0=0 ; k0<N_OF_REQUEST ; k0=k0+1 ) begin//for every possible request
			if(r_va_i[k0]) begin//the k0-th fifo_buffer mades a request
				vnet = vnet_of_the_request[k0];
				for( k1=0 ; k1<`N_OF_VC ; k1=k1+1 ) begin//check if there is a free vc in the requested vnet
					if(!g_va_o[k0] && vc_free[vnet*`N_OF_VC+k1]) begin
						vc_free[vnet*`N_OF_VC+k1] = 0;
						g_va_o[k0] = 1;
						g_vc_id_o[k0*N_BITS_VC_ID+vnet*`N_OF_VC+k1] = 1;
					end
				end//for
			end//if(r_va_i[k0])
		end//for
	end//always

endmodule//vc_allocator
