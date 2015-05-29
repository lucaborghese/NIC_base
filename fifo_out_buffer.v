//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	fifo_out_buffer 
// Project Name:	NIC_base
// Description:	d
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"

module fifo_out_buffer
	#(
	parameter	N_BITS_VNET_ID			=	2,//unsigned decimal encoding
	parameter	N_BITS_VC_ID			=	3,//one-hot encoding of all the vc
	parameter	N_BITS_CREDIT			=	4,
	parameter	N_BITS_PACKET_LENGHT	=	4
	)
	(
	input																	clk,
	input																	rst,

	//input pkt
	input				[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	pkt_i,//the entire packet that i have to save
	input				[N_BITS_VNET_ID-1:0]							vnet_id_i,//the vnet of the packet
	input																	is_valid_i,//if the current transmission is valid

	//VA side
	output	reg														r_va_o,//the module request the va stage for the stored packet
	output			[N_BITS_VNET_ID-1:0]							vnet_id_o,//the vnet of the packet
	input																	g_va_i,//grant from the va stage, the vc_id_i signal is valid
	input				[N_BITS_VC_ID-1:0]							vc_id_i,//contains the vc allocated, one-hot encoding

	//LA side and flit output
	output	reg														r_la_o,//request of the link for transmission
	output	reg	[`FLIT_WIDTH-1:0]								flit_o,//the flit to transmit
	output	reg														is_valid_o,//if i receive the grant, i can activate this signal
	input																	g_la_i,//i receive the grant, in the next cycle i can transmit the flit

	//fifo status pointer side
	input																	credit_in_i,//high if a credit come back
	output	reg														release_pointer_o,//when the packet is fully transmitted i can release the fifo pointer
	output			[N_BITS_VC_ID-1:0]							vc_id_o,//id of the fifo pointer that i can release

	//control signal
	output																free_slot_o//high if this buffer is free
	);

	//control register
	reg	[N_BITS_VNET_ID-1:0]	vnet_id_r;
	reg	[N_BITS_VC_ID-1:0]	vc_id_r;
	reg	[N_BITS_CREDIT-1:0]	credit_count_r;
	reg	[N_BITS_CREDIT-1:0]	next_credit_count;

	//computation of vnet_id_o and vc_id_o
	assign vnet_id_o = vnet_id_r;
	assign vc_id_o = vc_id_r;

	//update of vnet_id_r
	always @(posedge clk) begin
		if(store_pkt) begin
			vnet_id_r <= vnet_id_i;
		end else begin
			vnet_id_r <= vnet_id_r;
		end//else if(store_pkt)
	end//always

	//update of vc_id_r
	always @(posedge clk) begin
		if(g_va_i) begin
			vc_id_r <= vc_id_i;
		end else begin
			vc_id_r <= vc_id_r;
		end//else if(store_pkt)
	end//always

	//update of credit_count_r
	always @(posedge clk) begin
		if(g_va_i) begin
			credit_count_r <= `MAX_CREDIT;
		end else begin
			credit_count_r <= next_credit_count;
		end
	end//always

	//computation of next_credit_count
	always @(*) begin
		next_credit_count = credit_count_r;
		if(credit_in_i) begin//i receive a credit back
			next_credit_count = next_credit_count + 1;
		end
		if(g_la_i) begin//i send another flit
			next_credit_count = next_credit_count - 1;
		end
	end//always

	//buffer registers
	reg	[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	flit_buffer_r;
	reg	[N_BITS_PACKET_LENGHT-1:0]					transmitting_flit_pointer_r;
	reg	[N_BITS_PACKET_LENGHT-1:0]					next_transmitting_flit_pointer_r;
	wire														is_last_flit;

	//storing a new packet
	always @(posedge clk) begin
		if(store_pkt) begin
			flit_buffer_r <= pkt_i;
		end else begin
			flit_buffer_r <= flit_buffer_r;
		end
	end//always

	//update of transmitting_flit_pointer_r
	always @(posedge clk) begin
		if(store_pkt) begin
			transmitting_flit_pointer_r <= 0;
		end else begin
			if(!is_last_flit) begin
				transmitting_flit_pointer_r <= next_transmitting_flit_pointer_r;
			end else begin
				transmitting_flit_pointer_r <= transmitting_flit_pointer_r;
			end
		end//else if(store_pkt)
	end//always

	//update of next_transmitting_flit_pointer_r
	always @(posedge clk) begin
		if(store_pkt) begin
			next_transmitting_flit_pointer_r <= 0;
		end else begin
			if(g_la_i) begin
				next_transmitting_flit_pointer_r <= next_transmitting_flit_pointer_r + 1;
			end else begin
				next_transmitting_flit_pointer_r <= next_transmitting_flit_pointer_r;
			end
		end
	end//always

	//computation of is_last_flit
	assign is_last_flit = (flit_o[`FLIT_TYPE_BITS]==`HEAD_TAIL_FLIT || flit_o[`FLIT_TYPE_BITS]==`TAIL_FLIT) ? 1 : 0;

	//computation of flit_o
	integer k0;
	always @(*) begin
		for( k0=0 ; k0<`FLIT_WIDTH ; k0=k0+1 ) begin
			flit_o[k0] = flit_buffer_r[transmitting_flit_pointer_r*`FLIT_WIDTH+k0];
		end//for
	end//always

	//FSM
	//input pkt:					is_valid_i
	//input VA side:				g_va_i
	//input LA side:				g_la_i
	//input control signal:		is_last_flit
	//output VA side:				r_va_o
	//output LA side: 			r_la_o, is_valid_o, release_pointer_o
	//output control signal:	store_pkt
	localparam	IDLE				=	2'b00;
	localparam	VA_REQUEST		=	2'b01;
	localparam	TRANSMISSION	=	2'b10;
	reg	[1:0]	state;
	reg	[1:0]	next_state;
	//control signal
	reg	store_pkt;

	//computation of is_valid_o, when a g_la_i is received the next cycle a valid packet will be transmitted
	always @(posedge clk) begin
		if(g_la_i) begin
			is_valid_o <= 1;
		end else begin
			is_valid_o <= 0;
		end//else if(g_la_i)
	end//always

	//computation of next_state and control signal
	always @(*) begin
		case (state)
			IDLE: begin
				release_pointer_o = 0;
				r_va_o = 0;
				r_la_o = 0;
				if(is_valid_i) begin//a new pkt arrives
					next_state = VA_REQUEST;
					store_pkt = 1;
				end else begin
					next_state = IDLE;
					store_pkt = 0;
				end//else if(is_valid_i)
			end//IDLE
			VA_REQUEST: begin
				release_pointer_o = 0;
				r_va_o = 1;
				r_la_o = 0;
				store_pkt = 0;
				if(g_va_i) begin
					next_state = TRANSMISSION;
				end else begin
					next_state = VA_REQUEST;
				end//else if(g_va_i)
			end//VA_REQUEST
			TRANSMISSION: begin
				release_pointer_o = 0;
				r_va_o = 0;
				r_la_o = 1;
				if(!credit_count_r) begin
					r_la_o = 0;
				end
				store_pkt = 0;
				if(is_last_flit && is_valid_o) begin
					r_la_o = 0;
					next_state = IDLE;
					release_pointer_o = 1;
				end else begin
					next_state = TRANSMISSION;
				end//else if(g_la_i && is_last_flit)
			end//TRANSMISSION
			default: begin
				release_pointer_o = 0;
				r_va_o = 0;
				r_la_o = 0;
				store_pkt = 0;
				next_state = IDLE;
			end
		endcase
	end//always

	//update of state
	always @(posedge clk) begin
		if(rst) begin
			state <= IDLE;
		end else begin
			state <= next_state;
		end//else if(rst)
	end//always
	//end FSM

	//computation of free_slot_o
	assign free_slot_o = (state==IDLE) ? 1 : 0;

endmodule//fifo_out_buffer
