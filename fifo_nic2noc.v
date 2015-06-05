//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	fifo_nic2noc 
// Project Name:	NIC_base
// Description:	fifo
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"

module fifo_nic2noc
	#(
	parameter	N_TOT_OF_VC		=	6,//`N_OF_VC*`N_OF_VN
	parameter	N_BITS_POINTER	=	5//clog2(N_FIFO_BUFFER)
	)
	(
	input	clk,
	input	rst,

	//input NoC side
	input				[N_TOT_OF_VC-1:0]						credit_signal_i,
	input				[N_TOT_OF_VC-1:0]						free_signal_i,
	output			[`FLIT_WIDTH-1:0]						out_link_o,
	output														is_valid_o,

	//wb_slave_interface side
	input				[N_TOT_OF_VC-1:0]						g_fifo_pointer_i,//the i-th vc has been allocated from VA
	input				[N_TOT_OF_VC*N_BITS_POINTER-1:0]	g_fifo_out_buffer_id_i,//which fifo_out_buffer has been allocated for the i-th pointer
	input				[N_TOT_OF_VC-1:0]						release_pointer_i,//if the i-th bit is high the i-th pointer will pass from busy to idle
	output			[N_TOT_OF_VC-1:0]						credit_signal_o,//high if the i-th vc return a credit
	output			[N_TOT_OF_VC*N_BITS_POINTER-1:0]	fifo_pointed_o,//which fifo must obtain the credit
	input				[`FLIT_WIDTH-1:0]						in_link_i,
	input															is_valid_i,

	//vc_allocator side
	output			[N_TOT_OF_VC-1:0]						fifo_pointer_state_o
	);

	genvar i;

	//bypass of in_link_i and is_valid_i
	assign out_link_o = in_link_i;
	assign is_valid_o = is_valid_i;

	//pointer
	reg	[N_BITS_POINTER-1:0]	fifo_pointer_r[N_TOT_OF_VC-1:0];
	wire	[N_BITS_POINTER-1:0]	next_fifo_pointer[N_TOT_OF_VC-1:0];
	reg	[N_TOT_OF_VC-1:0]		fifo_status_r;//1 busy, 0 idle
	reg	[N_TOT_OF_VC-1:0]		next_fifo_status;
	reg	[N_TOT_OF_VC-1:0]		propagate_credit_r;//1 propagate, 0 do not propagate
	reg	[N_TOT_OF_VC-1:0]		next_propagate_credit;

	//update of fifo_pointer_r
	integer k0;
	always @(posedge clk) begin
		for( k0=0 ; k0<N_TOT_OF_VC ; k0=k0+1 ) begin
			fifo_pointer_r[k0] <= next_fifo_pointer[k0];
		end//for
	end//always

	//computation of next_fifo_pointer
	generate
		for( i=0; i<N_TOT_OF_VC ; i=i+1 ) begin : next_fifo_pointer_computation
			assign next_fifo_pointer[i] = (g_fifo_pointer_i[i]) ? g_fifo_out_buffer_id_i[(i+1)*N_BITS_POINTER-1:i*N_BITS_POINTER] : fifo_pointer_r[i];
		end//for
	endgenerate

	//update of fifo_status_r
	always @(posedge clk) begin
		if(rst) begin
			fifo_status_r <= 0;
		end else begin
			fifo_status_r <= next_fifo_status;
		end//else if(rst)
	end//always

	//computation of next_fifo_status
	always @(*) begin
		next_fifo_status = fifo_status_r;
		next_fifo_status = next_fifo_status | g_fifo_pointer_i;//the granted pointer must pass in busy state
		next_fifo_status = next_fifo_status & ~free_signal_i;//the released pointer pass in idle
	end//always

	//update of propagate_credit_r
	always @(posedge clk) begin
		if(rst) begin
			propagate_credit_r <= 0;
		end else begin
			propagate_credit_r <= next_propagate_credit;
		end
	end//always

	//computation of next_propagate_credit
	always @(*) begin
		next_propagate_credit = propagate_credit_r;
		next_propagate_credit = next_fifo_status | g_fifo_pointer_i;//the granted pointer must pass in busy state
		next_propagate_credit = next_fifo_status & ~release_pointer_i;//the released pointer pass in idle
	end//always

	//computation of fifo_pointer_state_o
	assign fifo_pointer_state_o = fifo_status_r;

	//computation of fifo_pointed_o
	generate
		for( i=0; i<N_TOT_OF_VC ; i=i+1 ) begin : fifo_pointed_o_computation
			assign fifo_pointed_o[N_BITS_POINTER*(i+1)-1:N_BITS_POINTER*i] = fifo_pointer_r[i];
		end//for
	endgenerate

	//forward of credit signal
	assign credit_signal_o = credit_signal_i & propagate_credit_r;

endmodule//fifo_nic2noc
