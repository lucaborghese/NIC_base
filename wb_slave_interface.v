//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	wb_slave_interface 
// Project Name:	NIC_base 
// Description:	slave interface of the NiC. This is a special implementation, 
//						this module receive the ACK(and the reply) when the master of the NiC
//						so it has an ACK_I.
//						Furthermore it doesn't send the reply for a node, the master interface of the NiC does it,
//						so it hasn't an ACK_O.  
//						Of course this is transparent
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "message_buffer.v"
`include "fifo_out_buffer.v"

module wb_slave_interface
	#(
	parameter	N_BITS_BURST_LENGHT			=	7,
	parameter	N_BITS_PACKET_LENGHT			=	4,
	parameter	N_FIFO_OUT_BUFFER				=	6,
	parameter	N_BITS_FIFO_OUT_BUFFER		=	3,
	parameter	N_BITS_VNET_ID					=	2,
	parameter	N_TOT_OF_VC						=	6,
	parameter	N_BITS_CREDIT					=	4
	)
	(
	input																		clk,
	input																		rst,

	//on_the_fly_node2noc table side
	output	reg															new_pending_transaction_o,//high if the new_* signals are valid
	output			[`N_BIT_SRC_HEAD_FLIT-1:0]						new_sender_o,//sender of the new pending transaction
	output			[`N_BIT_DEST_HEAD_FLIT-1:0]					new_recipient_o,//recipient of the new pending transaction
	output			[`N_BIT_CMD_HEAD_FLIT-1:0]						new_transaction_type_o,//type of the new pending transaction

	//link_allocator side
	output			[N_FIFO_OUT_BUFFER-1:0]							r_la_o,//one bit for each fifo_out_buffer, if the i-th bit is high it requires LA stage
	input																		g_la_i,//one bit, if high someone obtain the LA stage
	input				[N_BITS_FIFO_OUT_BUFFER-1:0]					g_la_fifo_out_buffer_id_i,//unsigned decimal, which fifo_out_buffer obtain the LA stage

	//vc_allocator side
	output			[N_FIFO_OUT_BUFFER-1:0]							r_va_o,//one bit for each fifo_out_buffer, if the i-th bit is high it requires VA stage
	output			[N_FIFO_OUT_BUFFER*N_TOT_OF_VC-1:0]			r_vc_requested_o,//vc requested
	input				[N_FIFO_OUT_BUFFER-1:0]							g_va_i,//grant from VA, one for each fifo_out_buffer
	input				[N_FIFO_OUT_BUFFER*N_TOT_OF_VC-1:0]			g_va_vc_id_i,//signal attached at g_va_i, if g_va_i[i] is high the allocated vc is passed via one-hot encoding in g_va_vc_id_i[(i+1)*N_TOT_OF_VC-1:i*N_TOT_OF_VC])

	//WISHBONE bus side
	input																		CYC_I,
	input																		STB_I,
	input				[2:0]													CTI_I,
	input																		WE_I,
	input				[`BUS_DATA_WIDTH-1:0]							DAT_I,
	input				[`BUS_ADDRESS_WIDTH-1:0]						ADR_I,
	input				[`BUS_SEL_WIDTH-1:0]								SEL_I,
	input																		ACK_I,
	output																	RTY_O,
	output																	ERR_O,
	output	reg															STALL_O,
	output	reg															ACK_O,

	//fifo side
	output	reg	[N_TOT_OF_VC-1:0]									g_fifo_pointer_o,//the i-th vc as been allocated from VA
	output			[N_TOT_OF_VC*N_BITS_FIFO_OUT_BUFFER-1:0]	g_fifo_out_buffer_id_o,//if the i-th bit of g_fifo_pointer_o is high, this signal from [(i+1)*N_BITS_FIFO_OUT_BUFFER-1:i*N_BITS_FIFO_OUT_BUFFER] tells which fifo_out_buffer take it
	output	reg	[N_TOT_OF_VC-1:0]									release_pointer_o,//if the i-th bit is high the i-th pointer will pass from busy to idle
	input				[N_TOT_OF_VC-1:0]									credit_signal_i,//high if the i-th vc return a credit
	input				[N_TOT_OF_VC*N_BITS_FIFO_OUT_BUFFER-1:0]	fifo_pointed_i,//which fifo must obtain the credit
	output	reg	[`FLIT_WIDTH-1:0]									out_link_o,//flit from a fifo_out_buffer that won the LA stage the previous cycle
	output	reg															is_valid_o
	);

	assign RTY_O = 0;
	assign ERR_O = 0;

	genvar i;

	//this signal is used to understand when a message has been received completely and must be moved from the message_buffer to a free fifo_out_buffer
	wire	is_valid_message;

	//if this signal is high we must store another chunk of the message from the bus in the message_buffer
	wire	store_chunk;
	assign store_chunk = ( ACK_I || (CYC_I && STB_I) );

	//computation of ACK_O DA CONTROLLARE
	always @(posedge clk) begin
		if(STB_I && CYC_I && WE_I) begin
			ACK_O <= 1;
		end else begin
			ACK_O <= 0;
		end
	end

	//if this signal is high there is at least one fifo_out_buffer free and free_space_pointer point at one of this
	wire	[N_FIFO_OUT_BUFFER-1:0]	fifo_out_buffer_status;//i-th bit 1, i-th buffer free, busy otherwise
	wire	free_space_available;
	wire	[N_BITS_FIFO_OUT_BUFFER-1:0]	free_space_pointer;
	assign free_space_available = (fifo_out_buffer_status!=0) ? 1 : 0;
	assign free_space_pointer = ff1(fifo_out_buffer_status,N_FIFO_OUT_BUFFER);

	//if this signal is high the message buffer must be cleared
	reg	clear_buffer;
	reg	reply_for_wb_master_interface;

	//FSM
	//input WB side:									CYC_I, STB_I, ACK_I
	//input control signal:							free_space_available, is_valid_message
	//output WB side:									STALL_O
	//output message_buffer internal module:	clear_buffer, reply_for_wb_master_interface
	//output on_the_fly_table:						new_pending_transaction_o
	localparam IDLE										=	3'b000;
	localparam WB_CYCLE_WRITE							=	3'b001;
	localparam WB_CYCLE_READ							=	3'b010;
	localparam WB_CYCLE_READ_WAIT_MASTER_REPLY	=	3'b011;
	localparam RECEIVE									=	3'b100;
	reg	[2:0]	state;
	reg	[2:0]	next_state;

	//state update
	always @(posedge clk) begin
		if(rst) begin
			state <= IDLE;
		end else begin
			state <= next_state;
		end//else if(rst)
	end//always

	//computation of output and next_state
	always @(*) begin
		case(state)
			IDLE: begin
				new_pending_transaction_o = 0;
				clear_buffer = 0;
				STALL_O = 0;
				next_state = IDLE;
				reply_for_wb_master_interface = 0;
				if(free_space_available) begin
					if(ACK_I) begin
						next_state = RECEIVE;
					end else begin
						if(CYC_I) begin
							if(WE_I) begin//write
								next_state = WB_CYCLE_WRITE;
							end else begin//read
								next_state = WB_CYCLE_READ;
							end//else if(WE_I)
						end//if(CYC_I)
					end//else if(ACK_I)
				end else begin
					STALL_O = 1;
				end//else if(free_space_available)
			end//IDLE
			WB_CYCLE_WRITE: begin
				STALL_O = 0;
				new_pending_transaction_o = 0;
				reply_for_wb_master_interface = 0;
				if(is_valid_message) begin
					next_state = IDLE;
					clear_buffer = 1;
				end else begin
					next_state = WB_CYCLE_WRITE;
					clear_buffer = 0;
				end//else if(is_valid_message)
			end//WB_CYCLE_WRITE
			WB_CYCLE_READ: begin
				STALL_O = 0;
				if(is_valid_message) begin
					next_state = WB_CYCLE_READ_WAIT_MASTER_REPLY;
					clear_buffer = 1;
					new_pending_transaction_o = 1;
				end else begin
					next_state = WB_CYCLE_READ;
					clear_buffer = 0;
					new_pending_transaction_o = 0;
				end//else if(is_valid_message)
			end//WB_CYCLE_READ
			WB_CYCLE_READ_WAIT_MASTER_REPLY: begin
				STALL_O = 0;
				clear_buffer = 0;
				new_pending_transaction_o = 0;
				reply_for_wb_master_interface = 0;
				if(!free_space_available) begin
					STALL_O = 1;
				end//if(!free_space_available)
				if(CYC_I) begin//when CYC_I go down the WB_CYCLE_READ terminates
					next_state = WB_CYCLE_READ_WAIT_MASTER_REPLY;
				end else begin
					next_state = IDLE;
				end//
			end//WB_CYCLE_READ_WAIT_MASTER_REPLY
			RECEIVE: begin
				STALL_O = 0;
				new_pending_transaction_o = 0;
				reply_for_wb_master_interface = 1;
				if(is_valid_message) begin
					next_state = IDLE;
					clear_buffer = 1;
				end else begin
					next_state = RECEIVE;
					clear_buffer = 0;
				end//else if(is_valid_message)
			end//RECEIVE
			default: begin
				STALL_O = 1;
				clear_buffer = 1;
				new_pending_transaction_o = 0;
				next_state = IDLE;
			end//default
		endcase
	end//always
	//end FSM

	//message_buffer
	wire	[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	pkt_from_message_buffer;
	wire	[N_BITS_VNET_ID-1:0]							vnet_id_from_message_buffer;
	message_buffer
		#(
		.N_BITS_VNET_ID(N_BITS_VNET_ID),
		.N_BITS_BURST_LENGHT(N_BITS_BURST_LENGHT)
		)
		message_buffer
		(
		.clk(clk),
		.rst(rst),

		//input
		.ADR_I(ADR_I),
		.DAT_I(DAT_I),
		.SEL_I(SEL_I),
		.WE_I(WE_I),
		.is_valid_i(store_chunk),
		.clear_buffer_i(clear_buffer),
		.reply_for_wb_master_interface_i(reply_for_wb_master_interface),
		//output
		.pkt_o(pkt_from_message_buffer),
		.vnet_id_o(vnet_id_from_message_buffer),
		.is_valid_o(is_valid_message)
		);

	//generation of N_FIFO_OUT_BUFFER fifo_out_buffer
	//computation of every is_valid_i for each fifo_out_buffer
	wire	[N_FIFO_OUT_BUFFER-1:0]	is_valid_for_fifo_out_buffer;
	assign is_valid_for_fifo_out_buffer = (is_valid_message) ? 1 << free_space_pointer : 0;

	//computation of every g_la_i for each fifo_out_buffer
	wire	[N_FIFO_OUT_BUFFER-1:0] g_la_for_fifo_out_buffer;
	assign g_la_for_fifo_out_buffer = (g_la_i) ? 1 << g_la_fifo_out_buffer_id_i : 0;

	//collectin vnet_of_the_request
	wire [N_BITS_VNET_ID-1:0] vnet_of_the_request[N_FIFO_OUT_BUFFER-1:0];

	//collection of flit_o arriving from every fifo_out_buffer and selecting propagating the valid one
	wire	[`FLIT_WIDTH-1:0]	flits_from_fifo_out_buffer[N_FIFO_OUT_BUFFER-1:0];

	//collection of is_valid_o signal from each fifo_out_buffer
	wire	[N_FIFO_OUT_BUFFER-1:0] is_valid_from_fifo_out_buffer;

	//collection of release_pointer_o signal from each fifo_out_buffer
	wire	[N_FIFO_OUT_BUFFER-1:0] release_pointer_from_fifo_out_buffer;

	//collection of vc_id_o signal from each fifo_out_buffer(which vc must be released if release_pointer_o is high)
	wire	[N_TOT_OF_VC-1:0] vc_id_from_fifo_out_buffer[N_FIFO_OUT_BUFFER-1:0];

	//computation of every credit_in_i for each fifo_out_buffer
	reg	[N_FIFO_OUT_BUFFER-1:0] credit_in_for_fifo_out_buffer;
	wire	[N_BITS_FIFO_OUT_BUFFER-1:0] fifo_pointed[N_TOT_OF_VC-1:0];
	generate
		for( i=0 ; i<N_TOT_OF_VC ; i=i+1 ) begin : fifo_pointed_computation
			assign fifo_pointed[i] = fifo_pointed_i[(i+1)*N_BITS_FIFO_OUT_BUFFER-1:i*N_BITS_FIFO_OUT_BUFFER];
		end//for
	endgenerate
	integer k0;
	always @(*) begin
		credit_in_for_fifo_out_buffer = 0;
		for( k0=0; k0<N_TOT_OF_VC ; k0=k0+1 ) begin
			credit_in_for_fifo_out_buffer[fifo_pointed[k0]] = credit_signal_i[k0];
		end//for
	end//always
	
	generate
		for( i=0; i<N_FIFO_OUT_BUFFER ; i=i+1 ) begin : fifo_out_buffer_generation
			fifo_out_buffer
				#(
				.N_BITS_VNET_ID(N_BITS_VNET_ID),
				.N_BITS_VC_ID(N_TOT_OF_VC),
				.N_BITS_CREDIT(N_BITS_CREDIT),
				.N_BITS_PACKET_LENGHT(N_BITS_PACKET_LENGHT)
				)
				fifo_out_buffer
				(
				.clk(clk),
				.rst(rst),

				//pkt input
				.pkt_i(pkt_from_message_buffer),
				.vnet_id_i(vnet_id_from_message_buffer),
				.is_valid_i(is_valid_for_fifo_out_buffer[i]),
				//VA side
				.r_va_o(r_va_o[i]),
				.vnet_id_o(vnet_of_the_request[i]),
				.g_va_i(g_va_i[i]),
				.vc_id_i(g_va_vc_id_i[(i+1)*N_TOT_OF_VC-1:i*N_TOT_OF_VC]),
				//LA side
				.r_la_o(r_la_o[i]),
				.g_la_i(g_la_for_fifo_out_buffer[i]),
				//fifo_nic2noc side
				.flit_o(flits_from_fifo_out_buffer[i]),
				.is_valid_o(is_valid_from_fifo_out_buffer[i]),
				.release_pointer_o(release_pointer_from_fifo_out_buffer[i]),
				.vc_id_o(vc_id_from_fifo_out_buffer[i]),
				.credit_in_i(credit_in_for_fifo_out_buffer[i]),
				//buffer status
				.free_slot_o(fifo_out_buffer_status[i])
				);
		end//for
	endgenerate

	//computation of is_valid_o and out_link_o from flits_from_fifo_out_buffer and is_valid_from_fifo_out_buffer
	//it should be only one bit high in is_valid_from_fifo_out_buffer
	wire	out_required;
	assign out_required = is_valid_from_fifo_out_buffer!=0;

	wire	[N_BITS_FIFO_OUT_BUFFER-1:0]	valid_flit_id;
	assign valid_flit_id = ff1(is_valid_from_fifo_out_buffer,N_FIFO_OUT_BUFFER);

	always @(*) begin
		is_valid_o = 0;
		out_link_o = 0;
		if(out_required) begin
			is_valid_o = 1;
			out_link_o = flits_from_fifo_out_buffer[valid_flit_id];
		end//if(out_required)
	end//always

	//computation of release_pointer_o(for fifo_nic2noc) from release_pointer_from_fifo_out_buffer and vc_id_from_fifo_out_buffer
	integer k1;
	always @(*) begin
		release_pointer_o = 0;
		for( k1=0; k1<N_FIFO_OUT_BUFFER ; k1=k1+1 ) begin
			if(release_pointer_from_fifo_out_buffer[k1]) begin
				release_pointer_o[ff1(vc_id_from_fifo_out_buffer[k1],N_TOT_OF_VC)] = 1;
			end//if(release_pointer_from_fifo_out_buffer[k1])
		end//for
	end//always

	//computation of new_sender_o, new_recipient_o and new_transaction_type_o from pkt_from_message_buffer
	assign new_sender_o = pkt_from_message_buffer[`SRC_BITS_HEAD_FLIT];
	assign new_recipient_o = pkt_from_message_buffer[`DEST_BITS_HEAD_FLIT];
	assign new_transaction_type_o = pkt_from_message_buffer[`CMD_BITS_HEAD_FLIT];

	//computation of g_fifo_pointer_o and g_fifo_out_buffer_id_o from g_va_i and g_va_vc_id_i
	wire	[N_TOT_OF_VC-1:0]	g_va_vc_id[N_FIFO_OUT_BUFFER-1:0];
	reg	[N_BITS_FIFO_OUT_BUFFER-1:0]	g_fifo_out_buffer_id[N_TOT_OF_VC-1:0];
	generate
		for( i=0 ; i<N_FIFO_OUT_BUFFER ; i=i+1 ) begin : computation_of_g_va_vc_id
			assign g_va_vc_id[i] = g_va_vc_id_i[(i+1)*N_TOT_OF_VC-1:i*N_TOT_OF_VC];
		end//for
	endgenerate
	generate
		for( i=0; i<N_TOT_OF_VC ; i=i+1 ) begin : computation_of_g_fifo_out_buffer_id
			assign g_fifo_out_buffer_id_o[(i+1)*N_BITS_FIFO_OUT_BUFFER-1:i*N_BITS_FIFO_OUT_BUFFER] = g_fifo_out_buffer_id[i];
		end//for
	endgenerate
	integer k2;
	integer k3;
	integer k4;
	always @(*) begin
		k4 = 0;
		g_fifo_pointer_o = 0;
		for( k2=0 ; k2<N_TOT_OF_VC ; k2=k2+1 ) begin
			g_fifo_out_buffer_id[k2] = 0;
		end//for
		for( k3=0 ; k3<N_FIFO_OUT_BUFFER ; k3=k3+1 ) begin
			if(g_va_i[k3]) begin
				k4 = ff1(g_va_vc_id[k3],N_TOT_OF_VC);
				g_fifo_pointer_o[k4] = 1;
				g_fifo_out_buffer_id[k4] = k3;
			end
		end//for
	end//always

	//computation of r_vc_requested_o from vnet_of_the_request
	generate
		for( i=0 ; i<N_FIFO_OUT_BUFFER ; i=i+1 ) begin : computation_r_vc_requested_o
			assign r_vc_requested_o[(i+1)*N_TOT_OF_VC-1:i*N_TOT_OF_VC] = 1 << vnet_of_the_request[i]*`N_OF_VC;
		end//for
	endgenerate

endmodule//wb_slave_interface
