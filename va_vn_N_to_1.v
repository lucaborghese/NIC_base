//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	va_vn_N_to_1 
// Project Name:	NIC_base
// Description: 
//
//////////////////////////////////////////////////////////////////////////////////

module va_vn_N_to_1
	#(
	parameter N_OF_REQUEST			=	6,
	parameter N_BITS_N_OF_REQUEST	=	3,
	parameter N_OF_VC					=	2
	)
	(
	input													clk,
	input													rst,

	input				[N_OF_VC-1:0]					vc_free_i,
	input				[N_OF_REQUEST-1:0]			r_va_vn_i,
	output	reg	[N_OF_REQUEST-1:0]			g_va_vn_o,
	output	reg	[N_OF_REQUEST*N_OF_VC-1:0]	g_vc_o
	);

	`include "NIC_utils.vh"

	reg	[N_BITS_N_OF_REQUEST-1:0]	last_served_request_r;
	reg	[N_BITS_N_OF_REQUEST-1:0]	current_served_request;

	//update of served_request_r
	always @(posedge clk) begin
		if(rst) begin
			last_served_request_r <= 0;
		end else begin
			last_served_request_r <= current_served_request;
		end//else if(rst)
	end//always

	//computation of current_served_request, g_va_vn_o, g_vc_o
	reg [N_BITS_N_OF_REQUEST-1:0] eligible_request;
	integer k0;
	always @(*) begin
		current_served_request = last_served_request_r;
		eligible_request = current_served_request;
		g_va_vn_o = 0;
		g_vc_o = 0;
		if(r_va_vn_i && vc_free_i) begin
			for( k0=0 ; k0<N_OF_REQUEST ; k0=k0+1 ) begin
				if(r_va_vn_i[eligible_request]) begin
					current_served_request = eligible_request;
				end//if(r_va_vn_i[k0])
				eligible_request = (eligible_request<(N_OF_REQUEST-1)) ? eligible_request+1 : 0;
			end//for
			g_va_vn_o = 1 << current_served_request;
			g_vc_o = 1 << (current_served_request*N_OF_VC+ff1(vc_free_i,N_OF_VC));
		end//if(r_va_vn_i && vc_free_i)
	end//always

endmodule//va_vn_N_to_1
