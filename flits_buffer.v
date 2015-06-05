//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	flits_buffer 
// Project Name:	NIC_base 
// Description:	The flits buffer is filled by a router of the NoC with a packet(diveded in flits).
//						when an entire packet is received the content is transfered in another buffer
//						WISHBONE side.
//						NO SUPPORT TO NON ATOMIC ALLOCATION
//
//////////////////////////////////////////////////////////////////////////////////
`include	"NIC-defines.v"

module flits_buffer
	#(
	parameter N_BITS_POINTER = 3
	)
	(
	input																clk,//clock signal
	input																rst,//reset signal(synchronous reset implemented)

	//Router side
	input			[`FLIT_WIDTH-1:0]								in_link_i,//data link from the NoC's router
	input																is_valid_i,//high if there is a valid flit in in_link
	output	reg													credit_signal_o,//high if one flit buffer is emptied in this cycle, low otherwise
	output	reg													free_signal_o,//high if buffer in idle state, low otherwise

	//queue side
	input																g_pkt_to_msg_i,//grant signal of the next stage of the pipeline
	output															r_pkt_to_msg_o,//request signal for the next stage of the pipeline
	output		[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	out_link_o,//link used to transfer the packet in the next stage of the pipeline
																					//the first flit(starting from bit 0) is the head/head_tail,
																					//the second flit(starting from bit `FLIT_WIDTH) is the first body,
																					//etc.
	output		[`MAX_PACKET_LENGHT-1:0]					out_sel_o//number of valid information in the out_link, if the i-th bit is high the i-th flit is valid
	);

	genvar	i;

	//extract flit type information from in_link_i
	wire	[`N_BITS_FLIT_TYPE-1:0]	flit_type;
	assign flit_type = in_link_i[`FLIT_TYPE_BITS];

	//buffer and out_sel_o register
	reg	[`FLIT_WIDTH-1:0]				buffer_r[`MAX_PACKET_LENGHT-1:0];
	reg	[N_BITS_POINTER-1:0]			head_pointer_r;//pointer to head_flit(if present)
	reg	[N_BITS_POINTER-1:0]			tail_pointer_r;//next free buffer's slot
	reg	[`MAX_PACKET_LENGHT-1:0]	sel_r;//if the i-th bit is high r_buffer[i] had valid information 
	reg	[N_BITS_POINTER-1:0]			next_head_pointer;//pointer to head_flit(if present)
	reg	[N_BITS_POINTER-1:0]			next_tail_pointer;//next free buffer's slot
	reg	[`MAX_PACKET_LENGHT-1:0]	next_sel;

	//connect output(out_sel_o and out_link_o) wire WISHBONE side to the respective registers
	assign out_sel_o = sel_r;
	generate
		for ( i=0 ; i<`MAX_PACKET_LENGHT ; i=i+1 ) begin : out_link_connection
			assign out_link_o[i*`FLIT_WIDTH+`FLIT_WIDTH-1:i*`FLIT_WIDTH] = buffer_r[i];
		end//for
	endgenerate

	//FSM
	//input:	is_valid_i, flit_type, g_pkt_to_msg_i
	//output: r_pkt_to_msg_o, credit_signal_o, free_signal_o, store, clear_buffer
	localparam	IDLE							=	3'b001;
	localparam	RECEIVING_PACKET			=	3'b010;
	localparam	REQUEST_PACKET2MESSAGE	=	3'b100;
	reg	[2:0]	state;
	reg	[2:0]	next_state;
	//control signal for the buffer
	reg			store;//if high a new flit must be stored in r_buffer
	reg			clear_buffer;//if high r_buffer is emptied

	//next_state and output computation(free_signal_o and credit_signal_o) depending on the current state and input of the FSM
	always @(*) begin
		case(state)
			IDLE: begin
				clear_buffer = 0;
				free_signal_o = 0;
				if(is_valid_i) begin//NEW FLIT ARRIVE
					credit_signal_o = 1;
					store = 1;
					case(flit_type)
						`HEAD_FLIT: begin
							next_state = RECEIVING_PACKET;
						end//head_flit
						`HEAD_TAIL_FLIT: begin
							next_state = REQUEST_PACKET2MESSAGE;
						end//head_tail_flit
						default: begin
							next_state = IDLE;
						end//default
					endcase//flit_type
				end else begin//NO NEW FLIT ARRIVING
					next_state = IDLE;
					credit_signal_o = 0;
					store = 0;
				end//else if(is_valid)
			end//IDLE

			RECEIVING_PACKET: begin
				clear_buffer = 0;
				free_signal_o = 0;
				if(is_valid_i) begin//NEXT FLIT ARRIVE
					credit_signal_o = 1;
					store = 1;
					case(flit_type)
						`BODY_FLIT: begin
							next_state = RECEIVING_PACKET;
						end//body_flit
						`TAIL_FLIT: begin
							next_state = REQUEST_PACKET2MESSAGE;
						end//tail_flit
						default: begin
							next_state = IDLE;
						end//default
					endcase//flit_type
				end else begin//NO NEXT FLIT
					next_state = RECEIVING_PACKET;
					credit_signal_o = 0;
					store = 0;
				end//else if(is_valid)
			end//RECEIVING_PACKET

			REQUEST_PACKET2MESSAGE: begin
				credit_signal_o = 0;
				store = 0;
				if(g_pkt_to_msg_i) begin//GRANT RECEIVED FROM THE NEXT STAGE OF THE PIPELINE
					next_state = IDLE;
					free_signal_o = 1;
					clear_buffer = 1;
				end else begin//NO GRANT FROM THE NEXT STAGE SO WE MUST WAIT AND ASK THE REQUEST AGAIN
					next_state = REQUEST_PACKET2MESSAGE;
					free_signal_o = 0;
					clear_buffer = 0;
				end//else if(g_packet_to_message)
			end//REQUEST_PACKET2MESSAGE

			default: begin
				free_signal_o = 1;
				credit_signal_o = 0;
				store = 0;
				clear_buffer = 1;
				next_state = IDLE;
			end//default
		endcase//state
	end//always

	//state update
	always @(posedge clk) begin
		if(rst) begin//RESET
			state <= IDLE;
		end else begin//NO RESET
			state <= next_state;
		end//else if(rst)
	end//always

	//computation of r_pkt_to_msg_o depending only on the current state
	assign r_pkt_to_msg_o = (state==REQUEST_PACKET2MESSAGE) ? 1 : 0;
	//END FSM

	//head_pointer_r, tail_pointer_r and sel_r update
	always @(posedge clk) begin
		if(rst) begin//RESET SIGNAL
			sel_r <= 0;
			head_pointer_r <= 0;
			tail_pointer_r <= 0;
		end else begin//NO RESET SIGNAL
			sel_r <= next_sel;
			head_pointer_r <= next_head_pointer;
			tail_pointer_r <= next_tail_pointer;
		end//else if(rst)
	end//always

	//store a flit
	always @(posedge clk) begin
		if(store) begin
			buffer_r[tail_pointer_r] <= in_link_i;
		end//if(store)
	end//always

	//computation of next_sel, next_head_pointer, next_tail_pointer
	always @(*) begin
		next_sel = sel_r;
		next_head_pointer = head_pointer_r;
		next_tail_pointer = tail_pointer_r;
		if(clear_buffer) begin
			next_head_pointer = next_tail_pointer;
			next_sel = 0;
		end else begin
			if(store) begin
				next_sel = next_sel | ( 1 << tail_pointer_r );
				if(next_tail_pointer<`MAX_PACKET_LENGHT-1) begin
					next_tail_pointer = next_tail_pointer + 1;
				end else begin
					next_tail_pointer = 0;
				end//else if
			end//if(store)
		end//else if(clear_buffer)
	end//always
endmodule//flits_buffer
