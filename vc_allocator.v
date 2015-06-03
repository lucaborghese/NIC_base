//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	vc_allocator 
// Project Name:	NIC_base
// Description:	Virtual channel allocator, it receive the state of the router
//						buffer and assign the virtual channel to a packet
//
//////////////////////////////////////////////////////////////////////////////////
`include "va_vn_N_to_1.v"

module vc_allocator
	#(
	parameter	N_OF_REQUEST			=	6,
	parameter	N_BITS_N_OF_REQUEST	=	3,
	parameter	N_OF_VN					=	3,
	parameter	N_OF_VC					=	2,
	parameter	N_TOT_OF_VC				=	6
	)
	(
	input	clk,
	input	rst,

	//request
	input				[N_OF_REQUEST-1:0]						r_va_i,//if r_va_i[i] is high, the i-th fifo out buffer require VA stage
	input				[N_OF_REQUEST*N_TOT_OF_VC-1:0]		r_vc_requested_i,//vc that the fifo_out_buffer requires
	output	wire	[N_OF_REQUEST-1:0]						g_va_o,
	output	wire	[N_OF_REQUEST*N_TOT_OF_VC-1:0]		g_vc_id_o,//one-hot encoding for every request

	//state of the fifo pointer(one for vc*vn)
	input				[N_TOT_OF_VC-1:0]							fifo_pointer_state_i//signal from the fifo_nic2noc module, if high the i-th bit means that the i-th vc is busy
	);

	genvar i;
	genvar j;

	wire [N_TOT_OF_VC-1:0] free_vc;
	assign free_vc = ~fifo_pointer_state_i;

	wire [N_OF_REQUEST-1:0]	vn_required[N_OF_VN-1:0];
	generate
		for( i=0 ; i<N_OF_VN ; i=i+1 ) begin : computation_vn_required
			for( j=0 ; j<N_OF_REQUEST ; j=j+1 ) begin : internal_computation_vn_required
				assign vn_required[i][j] = r_va_i[j] & r_vc_requested_i[j*N_TOT_OF_VC+(i+1)*N_OF_VC-1:j*N_TOT_OF_VC+i*N_OF_VC]!=0;
			end//for(j)
		end//for(i)
	endgenerate

	//generation of N_OF_VN virtual channel allocator
	wire [N_OF_REQUEST-1:0] g_va_from_va_vn[N_OF_VN-1:0];
	wire [N_OF_REQUEST*N_OF_VC-1:0] g_vc_from_va_vn[N_OF_VN-1:0];
	generate
		for( i=0 ; i<N_OF_VN ; i=i+1 ) begin : va_vn_generation
			va_vn_N_to_1
				#(
				.N_OF_REQUEST(N_OF_REQUEST),
				.N_BITS_N_OF_REQUEST(N_BITS_N_OF_REQUEST),
				.N_OF_VC(N_OF_VC)
				)
				va_vn
				(
				.clk(clk),
				.rst(rst),

				.vc_free_i(free_vc[(i+1)*N_OF_VC-1:i*N_OF_VC]),
				.r_va_vn_i(vn_required[i]),
				.g_va_vn_o(g_va_from_va_vn[i]),
				.g_vc_o(g_vc_from_va_vn[i])
				);
		end//for
	endgenerate

	//computation of g_va_o from g_va_from_va_vn
	wire [N_OF_VN-1:0] g_va_for_each_request[N_OF_REQUEST-1:0];
	generate
		for( i=0 ; i<N_OF_REQUEST ; i=i+1 ) begin : computation_g_va_for_each_request
			for( j=0 ; j<N_OF_VN ; j=j+1 ) begin : internal_computation_g_va_for_each_request
				assign g_va_for_each_request[i][j] = g_va_from_va_vn[j][i];
			end//for(j)
			assign g_va_o[i] = (g_va_for_each_request[i]) ? 1 : 0;
		end//for(i)
	endgenerate

	//computation of g_vc_id_o from g_vc_from_va_vn
	generate
		for( i=0 ; i<N_OF_REQUEST ; i=i+1 ) begin : computation_g_vc_id_o
			for( j=0 ; j<N_OF_VN ; j=j+1 ) begin : internal_computation_g_vc_id_o
				assign g_vc_id_o[i*N_TOT_OF_VC+(j+1)*N_OF_VC-1:i*N_TOT_OF_VC+j*N_OF_VC] = g_vc_from_va_vn[j][(i+1)*N_OF_VC-1:i*N_OF_VC];
			end//for(j)
		end//for(i)
	endgenerate

endmodule//vc_allocator
