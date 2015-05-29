//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	link_allocator 
// Project Name:	NIC_base
// Description:	it receive N_REQEUST_SIGNAL signals, if the i-th signal is high it means that it requires
//						the link. In output produce an unsigned decimal representation of the channel that can
//						pass the link in the next cycle
//
//////////////////////////////////////////////////////////////////////////////////
module link_allocator
	#(
	parameter	N_REQUEST_SIGNAL	=	6,
	parameter	N_BITS_POINTER		=	3
	)
	(
	input																	clk,
	input																	rst,

	//fifo side
	input				[N_REQUEST_SIGNAL-1:0]						r_la_i,
	output	reg														g_la_o,
	output			[N_BITS_POINTER-1:0]							g_channel_id_o
	);

	reg	[N_BITS_POINTER-1:0]	last_served_channel_r;
	reg	[N_BITS_POINTER-1:0]	next_served_channel;

	//last_channel_served_r update
	always @(posedge clk) begin
		if(rst) begin
			last_served_channel_r <= 0;
		end else begin
			last_served_channel_r <= next_served_channel;
		end
	end//always

	//computation of g_channel_o
	assign g_channel_id_o = next_served_channel;

	//computation of next_served_channel
	integer k0;
	reg	[N_BITS_POINTER-1:0]	eligible_channel;
	always @(*) begin
		next_served_channel = last_served_channel_r;
		eligible_channel = last_served_channel_r;
		g_la_o = 0;
		for( k0=0 ; k0<N_REQUEST_SIGNAL ; k0=k0+1 ) begin
			if(r_la_i[eligible_channel]) begin
				g_la_o = 1;
				next_served_channel = eligible_channel;
			end
			//update eligible_channel for the next iteration
			if(eligible_channel==0) begin
				eligible_channel = N_REQUEST_SIGNAL-1;
			end else begin
				eligible_channel = eligible_channel - 1;
			end
		end//for
	end//always

endmodule//link_allocator
