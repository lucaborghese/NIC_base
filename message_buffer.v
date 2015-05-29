//////////////////////////////////////////////////////////////////////////////////
//  
// Module Name:	message_buffer 
// Project Name:	NIC_base
// Description:	Buffer for a message from a bus transaction
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "msg_to_pkt.v"

module message_buffer
	#(
	parameter	N_BITS_VNET_ID			=	2,
	parameter	N_BITS_BURST_LENGHT	=	5
	)
	(
	input	clk,
	input	rst,

	//data_in and control signal
	input			[`BUS_ADDRESS_WIDTH-1:0]					ADR_I,
	input			[`BUS_DATA_WIDTH-1:0]						DAT_I,
	input			[`BUS_SEL_WIDTH-1:0]							SEL_I,
	input																WE_I,
	input																is_valid_i,//if high the signal above are valid
	input																clear_buffer_i,//if valid the message stored in the buffer must be transformed in packet and sent out
	//data_out
	output		[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	pkt_o,
	output		[N_BITS_VNET_ID-1:0]							vnet_id_o,
	output															is_valid_o
	);

	//buffer
	reg	[`BUS_ADDRESS_WIDTH-1:0]	address_buffer_r;
	reg	[`BUS_DATA_WIDTH-1:0]		data_buffer_r[`MAX_BURST_LENGHT-1:0];
	reg	[`BUS_SEL_WIDTH-1:0]			sel_r[`MAX_BURST_LENGHT-1:0];
	reg	[N_BITS_BURST_LENGHT-1:0]	free_data_pointer_r;
	reg	[N_BITS_BURST_LENGHT-1:0]	next_free_data_pointer;
	
	//update of free_data_pointer_r
	always @(posedge clk) begin
		if(rst || clear_buffer_i) begin
			free_data_pointer_r <= 0;
		end else begin
			free_data_pointer_r <= next_free_data_pointer;
		end
	end//always

	//computation of next_free_data_pointer
	always @(*) begin
		next_free_data_pointer = free_data_pointer_r;
		if(is_valid_i) begin
			next_free_data_pointer = next_free_data_pointer + 1;
		end//if(is_valid_i)
	end//always

	//storing a new element
	integer k0;
	always @(posedge clk) begin
		if(rst || clear_buffer_i) begin
			for( k0=0 ; k0<`MAX_BURST_LENGHT ; k0=k0+1 ) begin
				sel_r[k0] <= 0;
			end//for
		end else begin
			if(is_valid_i) begin
				if(free_data_pointer_r==0) begin
					address_buffer_r <= ADR_I;
				end
				data_buffer_r[free_data_pointer_r] <= DAT_I;
				sel_r[free_data_pointer_r] <= SEL_I;
			end//if(is_valid_i)
		end//else if(rst || clear_buffer_i)
	end//always

	//computation of is_valid_o, it understand when a message is complete DA FARE
	//	assign is_valid_o = ;

	//computation of vnet_id_o DA FARE
	//something using address_buffer_r

	//computation of pkt_o
	genvar i;
	wire	[`MAX_BURST_LENGHT*`BUS_DATA_WIDTH-1:0]	data_i;
	wire	[`MAX_BURST_LENGHT*`BUS_SEL_WIDTH-1:0]		sel_i;
	generate
		for( i=0 ; i<`MAX_BURST_LENGHT ; i=i+1 ) begin : data_i_computation
			assign data_i[`BUS_DATA_WIDTH*(i+1)-1:`BUS_DATA_WIDTH*i] = data_buffer_r[i];
			assign sel_i[`BUS_SEL_WIDTH*(i+1)-1:`BUS_SEL_WIDTH*i] = sel_r[i];
		end//for
	endgenerate
	msg_to_pkt msg2pkt
		(
		.address_i(address_buffer_r),
		.data_i(data_i),
		.sel_i(sel_i),
		.pkt_o(pkt_o)
		);

endmodule//message_buffer
