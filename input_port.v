//////////////////////////////////////////////////////////////////////////////////
//
// Module Name:	input_port 
// Project Name:	NIC_base
// Description:	input port router side 
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "flits_buffer.v"

module input_port
	#(
	parameter N_TOT_OF_VC						=	6,
	parameter N_BITS_POINTER_FLITS_BUFFER	=	3,
	parameter N_BITS_POINTER					=	3//clog2(N_TOT_OF_VC)
	)
	(
	input	clk,
	input	rst,

	//Router side
	input			[`FLIT_WIDTH-1:0]								in_link_i,//data link from NoC's router
	input																is_valid_i,//high if there is a valid flit in in_link_i
	output		[N_TOT_OF_VC-1:0]								credit_signal_o,//high if one flit buffer is emptied in this cycle, low otherwise. In this implementation it is not well used, it works only if buffer_r can contain an entire packet
	output		[N_TOT_OF_VC-1:0]								free_signal_o,//high if buffer_r change state from busy to idle

	//queue side
	input																stall_pkt_to_msg_i,//grant signal of the next stage of the pipeline
	output															r_pkt_to_msg_o,//request signal for the next stage of the pipeline
	output		[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	out_link_o//link used to transfer the packet in the next stage of the pipeline
																					//the first flit(starting from bit 0) is the head/head_tail,
																					//the second flit(starting from bit `FLIT_WIDTH) is the first body,
																					//etc.
//	output		[N_BITS_POINTER-1:0]							head_pointer_o,//tells which flit in out_link_o is the head(_tail)
//	output		[`MAX_PACKET_LENGHT-1:0]					out_sel_o//number of valid information in the out_link, if the i-th bit is high the i-th flit is valid
	);

	genvar i;

	//input signal for each flits_buffer(virtual channel)
	wire [`FLIT_WIDTH-1:0] in_link_for_flits_buffer[N_TOT_OF_VC-1:0];
	wire [N_TOT_OF_VC-1:0] is_valid_for_flits_buffer;
	wire [N_TOT_OF_VC-1:0] stall_pkt_to_msg_for_flits_buffer;

	//collection of output signal from each flits_buffer
	wire [N_TOT_OF_VC-1:0] r_pkt_to_msg_from_flits_buffer;
	wire [`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0] out_link_from_flits_buffer[N_TOT_OF_VC-1:0];

	//generation of flits_buffers
	generate
		for( i=0 ; i<N_TOT_OF_VC ; i=i+1 ) begin : flits_buffer_generation
			flits_buffer
				#(
				.N_BITS_POINTER(N_BITS_POINTER_FLITS_BUFFER)
				)
				flits_buffer
				(
				.clk(clk),
				.rst(rst),

				//router side
				.in_link_i(in_link_for_flits_buffer[i]),
				.is_valid_i(is_valid_for_flits_buffer[i]),
				.credit_signal_o(credit_signal_o[i]),
				.free_signal_o(free_signal_o[i]),
				//queue side
				.stall_pkt_to_msg_i(stall_pkt_to_msg_for_flits_buffer[i]),
				.r_pkt_to_msg_o(r_pkt_to_msg_from_flits_buffer[i]),
				.out_link_o(out_link_from_flits_buffer[i])
				);
		end//for
	endgenerate

	//in_link_for_flits_buffer computation
	generate
		for( i=0 ; i<N_TOT_OF_VC ; i=i+1 ) begin : in_link_for_flits_buffer_computation
			assign in_link_for_flits_buffer[i] = in_link_i;
		end
	endgenerate

	//is_valid_for_flits_buffer computation
	wire [`N_BITS_FLIT_VNET_ID-1:0] flit_vnet;
	wire [`N_BITS_FLIT_VC_ID-1:0] flit_vc;
	assign flit_vnet = in_link_i[`FLIT_VNET_ID_BITS];
	assign flit_vc = in_link_i[`FLIT_VC_ID_BITS];

	assign is_valid_for_flits_buffer = (is_valid_i) ? 1 << flit_vnet*`N_OF_VC+flit_vc : {N_TOT_OF_VC{1'b0}};

	//who will ask for r_pkt_to_msg(round robin)
	reg [N_BITS_POINTER-1:0] applicant_pkt2msg_id_r;
	reg [N_BITS_POINTER-1:0] next_applicant_pkt2msg_id;

	//update applicant_pkt2msg_id_r
	always @(posedge clk) begin
		if(rst)
			applicant_pkt2msg_id_r <= 0;
		else
			applicant_pkt2msg_id_r <= next_applicant_pkt2msg_id;
	end//always

	//computation of next_applicant_id
	integer k0;
	always @(*) begin
		next_applicant_pkt2msg_id = applicant_pkt2msg_id_r;
		if(r_pkt_to_msg_from_flits_buffer[applicant_pkt2msg_id_r]==0) begin//the current flits_buffer is not asking pkt2msg
			for( k0=0 ; k0<N_TOT_OF_VC ; k0=k0+1) begin
				if(r_pkt_to_msg_from_flits_buffer[next_applicant_pkt2msg_id]==0) begin
					next_applicant_pkt2msg_id = (next_applicant_pkt2msg_id==N_TOT_OF_VC-1) ? 0 : next_applicant_pkt2msg_id+1;
				end//if
			end//for
		end//if
	end//always

	//computation of r_pkt_to_msg_o
	assign r_pkt_to_msg_o = r_pkt_to_msg_from_flits_buffer[next_applicant_pkt2msg_id];

	//computation of stall_pkt_to_msg_for_flits_buffer
	generate
		for( i=0 ; i<N_TOT_OF_VC ; i=i+1 ) begin : stall_pkt_to_msg_for_flits_buffer_computation
			assign stall_pkt_to_msg_for_flits_buffer[i] = (next_applicant_pkt2msg_id==i) ? stall_pkt_to_msg_i : 1'b1;
		end//for
	endgenerate

	//computation of out_link_o
	assign out_link_o = out_link_from_flits_buffer[next_applicant_pkt2msg_id];

endmodule
