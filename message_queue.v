//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	message_queue 
// Project Name:	NIC_base
// Description:	queue of the PACKET2MESSAGE stage, a packet arrive from the input port(flits_buffers) and wait to be sent over the bus
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"

module message_queue
	#(
	parameter	N_BITS_POINTER				=	3,
	parameter	N_BITS_BURST_LENGHT		=	7
	)
	(
	input																	clk,
	input																	rst,
	
	//input port side
	input				[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	in_link_i,//data link from the input buffer
	input				[`MAX_PACKET_LENGHT-1:0]					in_sel_i,//number of valid information in the in_link, if the i-th bit is high the i-th flit is valid
	input																	r_pkt_to_msg_i,//request of storage from the input buffer
	output	reg														g_pkt_to_msg_o,//high if the queue can serve the request

	//interface side wb_master_interface
	output																r_bus_arbitration_o,//if high we require the arbitration over the bus
	output			[`BUS_ADDRESS_WIDTH-1:0]					address_o,//if r_bus_arbitration_o is high this signal contains the address that must be trasmitted on the WISHBONE
	output	reg	[`BUS_DATA_WIDTH-1:0]						data_o,//like above, but the signal contains the data
	output	reg	[`BUS_SEL_WIDTH-1:0]							sel_o,//like above, but contains the SEL_O signal
	output																transaction_type_o,//like above, but this signal contains the WE_O signal of WISHBONE
	output	reg	[N_BITS_BURST_LENGHT-1:0]					burst_lenght_o,//number of WISHBONE 'cycle' to transmit the message
	input																	next_data_i,//if high, the next chunk of the message must be load on data_o address_o
	input																	retry_i,//if high, we must restart the transmission of the current message
	input																	message_transmitted_i//if high the message pointed by head_pointer has been transmitted over the bus
	);

	genvar i;

	//queue registers(FIFO)
	reg	[`QUEUE_WIDTH-1:0]								valid_bit_r;//if the i-th bit is high head_queue_r[i] and data_queue_r[i] contains a message(at least there is the head_tail flit)
	reg	[`FLIT_WIDTH-1:0]									head_queue_r[`QUEUE_WIDTH-1:0];
	reg	[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]		data_queue_r[`QUEUE_WIDTH-1:0];
	reg	[(`MAX_PACKET_LENGHT-1)-1:0]					sel_r[`QUEUE_WIDTH-1:0];//if the i-th bit the i-th flit in data_queue_r[k] contains valid information
	reg	[N_BITS_POINTER-1:0]								head_pointer_r;//next message that must be sent over WISHBONE
	reg	[N_BITS_POINTER-1:0]								tail_pointer_r;//next free slot in queue

	//if there is at least one free slot in the queue
	wire free_space_available;//if high a free slot is available for storage
	assign free_space_available = (valid_bit_r[tail_pointer_r]==0) ? 1 : 0;

	//computation of message_available
	assign r_bus_arbitration_o = (valid_bit_r[head_pointer_r]!=0) ? 1 : 0;

	//computation of g_packet_to_message
	always @(posedge clk) begin
		if(rst) begin
			g_pkt_to_msg_o <= 0;
		end else begin
			if(free_space_available && r_pkt_to_msg_i && !g_pkt_to_msg_o) begin
				g_pkt_to_msg_o <= 1;
			end else begin
				g_pkt_to_msg_o <= 0;
			end
		end//else if(rst)
	end//always

	//storing a new message(valid_bit_r is updated in another always statement!!!)
	always @(posedge clk) begin
		if(rst) begin
			tail_pointer_r <= 0;
		end else begin
			if(g_pkt_to_msg_o) begin
				head_queue_r[tail_pointer_r] <= in_link_i[`FLIT_WIDTH-1:0];//storing head/head_tail flit
				data_queue_r[tail_pointer_r] <= in_link_i[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0];//storing data flit
				sel_r[tail_pointer_r] <= in_sel_i[`MAX_PACKET_LENGHT-1:1];
				if(tail_pointer_r==`QUEUE_WIDTH-1) begin//update tail_pointer_r
					tail_pointer_r <= 0;
				end else begin
					tail_pointer_r <= tail_pointer_r + 1;
				end
			end else begin
				tail_pointer_r <= tail_pointer_r;
			end//else if(g_packet_to_message)
		end//else if(rst)
	end//always

	//delete a message that has been sent over the bus(valid_bit_r is updated in another always statement!!!)
	always @(posedge clk) begin
		if(rst) begin
			head_pointer_r <= 0;
		end else begin
			if(message_transmitted_i) begin
				if(head_pointer_r==`QUEUE_WIDTH-1) begin//update head_pointer_r
					head_pointer_r <= 0;
				end else begin
					head_pointer_r <= head_pointer_r + 1;
				end
			end else begin
				head_pointer_r <= head_pointer_r;
			end//else if(message_transmitted)
		end//else if(rst)
	end//always

	//update of valid_bit_r
	always @(posedge clk) begin
		if(rst) begin
			valid_bit_r <= 0;
		end else begin
			case({ g_pkt_to_msg_o , message_transmitted_i })
				2'b01: begin//a message sent and no new arrive
					valid_bit_r[head_pointer_r] <= 0;
				end//2'b01
				2'b10: begin//no message sent and a new message arrive
					valid_bit_r[tail_pointer_r] <= 1;
				end//2'b10
				2'b11: begin//message sent and arrives
					valid_bit_r[head_pointer_r] <= 0;
					valid_bit_r[tail_pointer_r] <= 1;
				end//2'b11
				default: begin
					valid_bit_r <= valid_bit_r;
				end
			endcase
		end//else if(rst)
	end//always

	//signal used to compute data_o, address_o, sel_o, transaction_type_o, burst_lenght_o
	reg	[N_BITS_BURST_LENGHT-1:0]	current_message_chunk_pointer_r;//trace the current chunk of message that must be transmitted
	reg	[N_BITS_BURST_LENGHT-1:0]	next_current_message_chunk_pointer;

	//update of current_message_chunk_pointer_r
	always @(posedge clk) begin
		if(rst) begin
			current_message_chunk_pointer_r <= 0;
		end else begin
			current_message_chunk_pointer_r <= next_current_message_chunk_pointer;
		end//else if(rst)
	end//always

	//computation of next_current_message_chunk_pointer
	always @(*) begin
		next_current_message_chunk_pointer = current_message_chunk_pointer_r;
		if(message_transmitted_i || retry_i) begin
				next_current_message_chunk_pointer = 0;
		end else begin
			if(next_data_i) begin//next data is required
				next_current_message_chunk_pointer = next_current_message_chunk_pointer + 1;
			end//if(next_data_i && transaction_type_o)
		end//else if(message_transmitted_i || retry_i)
	end//always

	//computation of data_o
	wire	[`BUS_DATA_WIDTH-1:0]	current_message[`MAX_BURST_LENGHT-1:0];
	generate
		for( i=0 ; i<`MAX_BURST_LENGHT ; i=i+1 ) begin : current_message_computation
			assign current_message[i] = data_queue_r[head_pointer_r][(i+1)*`BUS_DATA_WIDTH-1:i*`BUS_DATA_WIDTH];
		end//for
	endgenerate
	always @(*) begin
		data_o = current_message[current_message_chunk_pointer_r];
	end//always

	//computation of address_o
	assign address_o = head_queue_r[head_pointer_r][`HEAD_FLIT_ADDRESS_BITS];

	//computation of sel_o DA FINIRE per ora sempre tutti 1
	always @(*) begin
		sel_o = 0;
		if(transaction_type_o) begin//if WRITE
			if(burst_lenght_o==1) begin//small packet(only head_tail)
				sel_o = ~0;//ERROR sel_o must be set with the lenght of a small message write
			end else begin
				if(current_message_chunk_pointer_r<burst_lenght_o-1) begin
					sel_o = ~0;
				end else begin
					sel_o = ~0;//ERROR sel_o must be set with the remain one of the last WB transaction of a big message write
				end
			end
		end else begin//if READ
			sel_o = ~0;//ERROR sel_o must be set with the remain one of a read(probably like write)
		end//else if(transaction_type_o)
	end//always

//	computation of transaction_type, if tha packet has a head_flit => write, if has a head_tail_flit => read
	assign transaction_type_o = (data_queue_r[head_pointer_r][`FLIT_TYPE_BITS]==`HEAD_TAIL_FLIT && read_request(data_queue_r[head_pointer_r][`CMD_BITS_HEAD_FLIT])) ? 0 : 1;

	//computation of burst_lenght_o
	always @(*) begin
		burst_lenght_o = `MAX_BURST_LENGHT;
		if(transaction_type_o && control_packet(data_queue_r[head_pointer_r][`CMD_BITS_HEAD_FLIT])) begin//if WRITE, check if is a little message or a big message
			burst_lenght_o = 1;
		end
	end//always

endmodule//message_queue
