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
	input			[`BUS_TGA_WIDTH-1:0]							TGA_I,
	input			[`BUS_TGC_WIDTH-1:0]							TGC_I,
	input																WE_I,
	input																reply_for_wb_master_interface_i,//if high, the stored packet is a reply for the wb_master_interface
	input																is_valid_i,//if high the signal above are valid
	input																clear_buffer_i,//if valid the message stored in the buffer must be transformed in packet and sent out
	//data_out
	output		[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	pkt_o,
	output	reg	[N_BITS_VNET_ID-1:0]						vnet_id_o,
	output															is_valid_o
	);

	`include "NIC_utils.vh"

	//buffer
	reg	[`BUS_ADDRESS_WIDTH-1:0]	address_buffer_r;
	reg	[`BUS_TGA_WIDTH-1:0]			tga_r;
	reg	[`BUS_TGC_WIDTH-1:0]			tgc_r;
	reg	[`BUS_DATA_WIDTH-1:0]		data_buffer_r[`MAX_BURST_LENGHT-1:0];
	reg	[`BUS_SEL_WIDTH-1:0]			sel_r[`MAX_BURST_LENGHT-1:0];
	reg	[N_BITS_BURST_LENGHT:0]		n_of_stored_chunk_r;
	reg	[N_BITS_BURST_LENGHT:0]		next_n_of_stored_chunk;

	//update of n_of_stored_chunk_r
	always @(posedge clk) begin
		if(rst || clear_buffer_i) begin
			n_of_stored_chunk_r <= 0;
		end else begin
			n_of_stored_chunk_r <= next_n_of_stored_chunk;
		end//if(rst)
	end//always

	//computation of next_n_of_stored_chunk
	always @(*) begin
		next_n_of_stored_chunk = n_of_stored_chunk_r;
		if(is_valid_i) begin
			next_n_of_stored_chunk = next_n_of_stored_chunk + 1;
		end
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
				if(n_of_stored_chunk_r==0) begin
					address_buffer_r <= ADR_I;
					tga_r <= TGA_I;
					tgc_r <= TGC_I;
				end
				data_buffer_r[n_of_stored_chunk_r] <= DAT_I;
				sel_r[n_of_stored_chunk_r] <= SEL_I;
			end//if(is_valid_i)
		end//else if(rst || clear_buffer_i)
	end//always

	//computation of r_msg2pkt from n_of_stored_chunk_r and address_buffer_r DA FARE
	reg r_msg2pkt;
	always @(*) begin
		r_msg2pkt = 0;
		if( ( n_of_stored_chunk_r==1 && data_buffer_r[0][`FLIT_TYPE_BITS]==`HEAD_TAIL_FLIT && WE_I && !reply_for_wb_master_interface_i ) || n_of_stored_chunk_r==`MAX_BURST_LENGHT) begin//if in the first message there is a head_tail flit
			r_msg2pkt = 1;
		end//if
	end//always

	//computation of is_valid_o
	assign is_valid_o = r_msg2pkt;

	//computation of vnet_id_o
	always @(*) begin
		vnet_id_o = 0;
		if(r_msg2pkt) begin
			vnet_id_o = pkt_o[`FLIT_VNET_ID_BITS];
		end
	end//always

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
		.tga_i(tga_r),
		.tgc_i(tgc_r),
		.WE_I(WE_I),
		.reply_for_wb_master_interface_i(reply_for_wb_master_interface_i),
		.r_msg2pkt_i(r_msg2pkt),
		.pkt_o(pkt_o)
		);

endmodule//message_buffer
