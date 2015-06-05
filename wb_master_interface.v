//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	wb_master_interface 
// Project Name:	NIC_base
// Description:	master interface of the WISHBONE bus, pipeline and block cycle are supported
//						it execute the transaction required from the queue.
//						This is a special implementation of a pipeline master(of course from the WISHBONE point of view IT IS a normal master)
//						When a read is employed, the wb_slave_interface stores the reply.
//						When a master node ask something at the NiC, is this modulo(the master) that reply not the slave.
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"

module wb_master_interface
	#(
	parameter	N_BITS_BURST_LENGHT	=	7
	)
	(
	input	clk,
	input	rst,

	//QUEUE side
	input																	r_bus_arbitration_i,//if high, there is a message in the queue that require arbitration
	input				[`BUS_ADDRESS_WIDTH-1:0]					address_i,//if r_bus_arbitration_i is high this signal contains the address that must be trasmitted on the WISHBONE
	input				[`BUS_DATA_WIDTH-1:0]						data_i,//like above, but the signal contains the data
	input				[(`BUS_DATA_WIDTH/`GRANULARITY)-1:0]	sel_i,//like above, but contains the SEL_O signal
	input																	transaction_type_i,//like above, but this signal contains the WE_O signal of WISHBONE
	input				[N_BITS_BURST_LENGHT-1:0]					burst_lenght_i,//number of WISHBONE 'cycle' to transmit the message
	output	reg														next_data_o,//if high, we require at the queue to load the next chunk of the message on data_i address_i
	output	reg														message_transmitted_o,//if high, we warn the queue that entire message has been sent over the bus
	output	reg														retry_o,//if high, tells the queue of restarting the transmission of the current message

	//on the fly table side
	input																	is_a_pending_transaction_i,//reply from the table, high if the message is a reply for a node
	output	reg														query_o,//high if we are querying the table
	output	reg														pending_transaction_executed_o,//high if the reply has been executed and we receive the ack
	output	reg	[`N_BIT_SRC_HEAD_FLIT-1:0]					query_sender_o,//local node that begin the transaction(PROBABLY NOT ALL THE BIT IN THE ADDRESS ARE USEFULL) 
	output	reg	[`N_BIT_DEST_HEAD_FLIT-1:0]				query_recipient_o,//remote node that generate the reply
	output	reg	[`N_BIT_CMD_HEAD_FLIT-1:0]					transaction_type_o,

	//wb_slave_interface side
	output	reg														performing_read_o,//unused

	//WISHBONE BUS signals
//	input																	CLK_I,
//	input																	RST_I,
	input				[`BUS_DATA_WIDTH-1:0]						DAT_I,//can be eliminated
	input																	ACK_I,
	input																	RTY_I,
	input																	ERR_I,
	input																	STALL_I,
	output	reg														CYC_O,
	output	reg														STB_O,
	output																WE_O,
	output			[`BUS_ADDRESS_WIDTH-1:0]					ADR_O,
	output			[`BUS_DATA_WIDTH-1:0]						DAT_O,
	output			[(`BUS_DATA_WIDTH/`GRANULARITY)-1:0]	SEL_O,
	output			[2:0]												CTI_O,
	output	reg														ACK_O,//this isn't a signal of the master, it is used in the pipeline implementation of this NiC when this module reply for the wb_slave_interface

	//WISHBONE arbiter signal
	input																	gnt_wb_i
	);

	//bypass of the signal address_i, data_i, sel_i and transaction_type
	assign DAT_O	=	data_i;
	assign ADR_O	=	address_i;
	assign SEL_O	=	sel_i;
	assign WE_O		=	transaction_type_i;
	//force CTI on classic cycle
	assign CTI_O	=	`CTI_CLASSIC_CYCLE;

	//register that count how many ack arrive from WISHBONE and control register of it
	reg	[N_BITS_BURST_LENGHT-1:0]		n_of_ack_r;
	reg	[N_BITS_BURST_LENGHT-1:0]		next_n_of_ack;
	reg											rst_n_of_ack;
	reg											increment_n_of_ack;
	//register that count how many chunk of the current message has been sent and control register of it
	reg	[N_BITS_BURST_LENGHT-1:0]		n_of_sent_chunk_r;
	reg	[N_BITS_BURST_LENGHT-1:0]		next_n_of_sent_chunk;
	reg											rst_n_of_chunk;
	reg											increment_n_of_chunk;

	//update of n_of_ack_r and n_of_sent_chunk_r
	always @(posedge clk) begin
		if(rst) begin
			n_of_ack_r <= 0;
			n_of_sent_chunk_r <= 0;
		end else begin
			n_of_ack_r <= next_n_of_ack;
			n_of_sent_chunk_r <= next_n_of_sent_chunk;
		end//else if(rst)
	end//always

	//computation of next_n_of_sent_chunk
	always @(*) begin
		if(rst_n_of_chunk) begin
			next_n_of_sent_chunk = 0;
		end else begin
			if(increment_n_of_chunk) begin
				next_n_of_sent_chunk = n_of_sent_chunk_r + 1;
			end else begin
				next_n_of_sent_chunk = n_of_sent_chunk_r;
			end//else if(increment_n_of_ack)
		end//else if(rst)
	end//always

	//computation of next_n_of_ack
	always @(*) begin
		if(rst_n_of_ack) begin
			next_n_of_ack = 0;
		end else begin
			if(increment_n_of_ack) begin
				next_n_of_ack = n_of_ack_r + 1;
			end else begin
				next_n_of_ack = n_of_ack_r;
			end//else if(increment_n_of_ack)
		end//else if(rst)
	end//always

	//computation of query_sender_o, query_recipient_o, transaction_type_o DA FARE

	//FSM
	//input queue side:						r_bus_arbitration_i, burst_lenght_i, transaction_type_i
	//input table side:						is_a_pending_transaction_i
	//input WISHBONE side:					ACK_I, RTY_I, ERR_I, STALL_I
	//input internal signal:				n_of_ack_r, n_of_sent_chunk_r
	//input WISHBONE arbiter:				gnt_wb_i
	//output queue side:						next_data_o, message_transmitted_o, retry_o
	//output table side:						query_o, pending_transaction_executed_o
	//output wb_slave_interface side:	performing_read_o
	//output WISHBONE side:					CYC_O, STB_O, ACK_O
	//output internal signal:				rst_n_of_ack, increment_n_of_ack, rst_n_of_chunk, increment_n_of_chunk
	localparam	IDLE 								=	4'b0000;
	localparam	REQUEST_WB_BUS					=	4'b0001;
	localparam	READ_CYCLE						=	4'b0010;
	localparam	READ_CYCLE_ACK_WAIT			=	4'b0011;
	localparam	READ_CYCLE_END					=	4'b0100;
	localparam	WRITE_CYCLE						=	4'b0101;
	localparam	WRITE_CYCLE_ACK_WAIT			=	4'b0110;
	localparam	WRITE_CYCLE_END				=	4'b0111;//for now equal to READ_CYCLE_END, these two state can be collapsed(for now)
	localparam	REPLY_PENDING_TRANSACTION	=	4'b1000;
	reg	[3:0]	state;
	reg	[3:0]	next_state;

	//next_state computation and control signal update
	always @(*) begin
		case(state)
			IDLE: begin
				next_data_o = 0;
				message_transmitted_o = 0;
				retry_o = 0;
				STB_O = 0;
				rst_n_of_ack = 1;
				increment_n_of_ack = 0;
				rst_n_of_chunk = 1;
				increment_n_of_chunk = 0;
				pending_transaction_executed_o = 0;
				ACK_O = 0;
				performing_read_o = 0;
				if(r_bus_arbitration_i) begin
					query_o = 1;
					if(is_a_pending_transaction_i) begin
						CYC_O = 0;
						next_state = REPLY_PENDING_TRANSACTION;
					end else begin
						CYC_O = 1;
						next_state = REQUEST_WB_BUS;
					end
				end else begin
					query_o = 0;
					CYC_O = 0;
					next_state = IDLE;
				end//else if(r_bus_arbitration)
			end//IDLE

			REQUEST_WB_BUS: begin
				CYC_O = 1;
				rst_n_of_ack = 0;
				increment_n_of_ack = 0;
				rst_n_of_chunk = 0;
				message_transmitted_o = 0;
				retry_o = 0;
				query_o = 0;
				pending_transaction_executed_o = 0;
				ACK_O = 0;
				if(!STALL_I && gnt_wb_i) begin//i have to start a transfer on the bus
					STB_O = 1;
					increment_n_of_chunk = 1;
					if(transaction_type_i) begin//WRITE transaction
						performing_read_o = 0;
						if(burst_lenght_i>1) begin
							next_state = WRITE_CYCLE;
							next_data_o = 1;
						end else begin
							next_state = WRITE_CYCLE_ACK_WAIT;
							next_data_o = 0;
						end//else if(burst_lenght)
					end else begin//READ transaction
						performing_read_o = 1;
						if(burst_lenght_i>1) begin
							next_state = READ_CYCLE;
							next_data_o = 1;
						end else begin
							next_state = READ_CYCLE_ACK_WAIT;
							next_data_o = 0;
						end//else if(burst_lenght)
					end//else if(transaction_type)
				end else begin//i do not have to start a bus cycle
					next_state = REQUEST_WB_BUS;
					STB_O = 0;
					increment_n_of_chunk = 0;
					next_data_o = 0;
					performing_read_o = 0;
				end//else if
			end//REQUEST_BUS

			READ_CYCLE: begin
				performing_read_o = 1;
				CYC_O = 1;
				STB_O = 1;
				rst_n_of_ack = 0;
				rst_n_of_chunk = 0;
				message_transmitted_o = 0;
				retry_o = 0;//DA DECIDERE
				query_o = 0;
				pending_transaction_executed_o = 0;
				ACK_O = 0;
				if(ACK_I) begin//if an ACK arrives i had to store the reply of the read and increment the ack counter
					increment_n_of_ack = 1;
				end else begin
					increment_n_of_ack = 0;
				end//else if(ack_i)
				if(STALL_I) begin//the slave insert a STALL
					next_state = READ_CYCLE;
					next_data_o = 0;
					increment_n_of_chunk = 0;
				end else begin
					if(burst_lenght_i>n_of_sent_chunk_r+1) begin//this is not the last cycle
						next_state = READ_CYCLE;
						next_data_o = 1;
						increment_n_of_chunk = 1;
					end else begin//i have to perform the last cycle
						next_state = READ_CYCLE_ACK_WAIT;
						next_data_o = 0;
						increment_n_of_chunk = 1;
					end//else if()
				end//else if(STALL_I)
			end//READ_CYCLE_TRANSMISSION

			READ_CYCLE_ACK_WAIT: begin
				performing_read_o = 1;
				CYC_O = 1;
				STB_O = 0;
				next_data_o = 0;
				increment_n_of_chunk = 0;
				rst_n_of_ack = 0;
				rst_n_of_chunk = 0;
				retry_o = 0;//DA DECIDERE
				query_o = 0;
				pending_transaction_executed_o = 0;
				ACK_O = 0;
				if(ACK_I) begin//a new ACK arrive
					increment_n_of_ack = 1;
					if(n_of_ack_r<burst_lenght_i-1) begin//this is not the last ack
						next_state = READ_CYCLE_ACK_WAIT;
						message_transmitted_o = 0;
					end else begin//this is the last ack that we are waiting
						next_state = READ_CYCLE_END;
						message_transmitted_o = 1;
					end//else if()
				end else begin
					next_state = READ_CYCLE_ACK_WAIT;
					message_transmitted_o = 0;
					increment_n_of_ack = 0;
				end//else if(ACK_I)
			end//READ_CYCLE_ACK_WAIT

			READ_CYCLE_END: begin//DA DEFINIRE L'INTERFACCIA CON LA FIFO PER ORA CANCELLO IL MESSAGGIO RICEVUTO E BASTA
				performing_read_o = 0;
				next_state = IDLE;
				CYC_O = 0;
				STB_O = 0;
				message_transmitted_o = 0;
				increment_n_of_ack = 0;
				increment_n_of_chunk = 0;
				rst_n_of_ack = 1;
				rst_n_of_chunk = 1;
				retry_o = 0;
				next_data_o = 0;
				query_o = 0;
				pending_transaction_executed_o = 0;
				ACK_O = 0;
			end//READ_CYCLE_END_REQUIRE_FIFO

			WRITE_CYCLE: begin
				performing_read_o = 0;
				CYC_O = 1;
				STB_O = 1;
				rst_n_of_ack = 0;
				rst_n_of_chunk = 0;
				message_transmitted_o = 0;
				retry_o = 0;//DA DECIDERE
				query_o = 0;
				pending_transaction_executed_o = 0;
				ACK_O = 0;
				if(ACK_I) begin//if an ACK arrives i had to increment the ack counter
					increment_n_of_ack = 1;
				end else begin
					increment_n_of_ack = 0;
				end//else if(ack_i)
				if(STALL_I) begin//the slave insert a STALL
					next_state = WRITE_CYCLE;
					next_data_o = 0;
					increment_n_of_chunk = 0;
				end else begin
					if(burst_lenght_i>n_of_sent_chunk_r+1) begin//this is not the last cycle
						next_state = WRITE_CYCLE;
						next_data_o = 1;
						increment_n_of_chunk = 1;
					end else begin//i have to perform the last cycle
						next_state = WRITE_CYCLE_ACK_WAIT;
						next_data_o = 0;
						increment_n_of_chunk = 1;
					end//else if()
				end//else if(STALL_I)
			end//WRITE_CYCLE_TRANSMISSION

			WRITE_CYCLE_ACK_WAIT: begin
				performing_read_o = 0;
				CYC_O = 1;
				STB_O = 0;
				next_data_o = 0;
				increment_n_of_chunk = 0;
				rst_n_of_ack = 0;
				rst_n_of_chunk = 0;
				retry_o = 0;//DA DECIDERE
				query_o = 0;
				pending_transaction_executed_o = 0;
				ACK_O = 0;
				if(ACK_I) begin//a new ACK arrive
					increment_n_of_ack = 1;
					if(n_of_ack_r<burst_lenght_i-1) begin//this is not the last ack
						next_state = WRITE_CYCLE_ACK_WAIT;
						message_transmitted_o = 0;
					end else begin//this is the last ack that we are waiting
						next_state = WRITE_CYCLE_END;
						message_transmitted_o = 1;
					end//else if()
				end else begin
					next_state = WRITE_CYCLE_ACK_WAIT;
					message_transmitted_o = 0;
					increment_n_of_ack = 0;
				end//else if(ACK_I)
			end//WRITE_CYCLE_ACK_WAIT

			WRITE_CYCLE_END: begin
				performing_read_o = 0;
				next_state = IDLE;
				CYC_O = 0;
				STB_O = 0;
				message_transmitted_o = 0;
				increment_n_of_ack = 0;
				increment_n_of_chunk = 0;
				rst_n_of_ack = 1;
				rst_n_of_chunk = 1;
				retry_o = 0;
				next_data_o = 0;
				query_o = 0;
				pending_transaction_executed_o = 0;
				ACK_O = 0;
			end//WRITE_CYCLE_END

			REPLY_PENDING_TRANSACTION: begin
				performing_read_o = 0;
				retry_o = 0;
				CYC_O = 0;
				STB_O = 0;
				rst_n_of_ack = 1;
				increment_n_of_ack = 0;
				rst_n_of_chunk = 0;
				query_o = 1;
				if(n_of_sent_chunk_r<burst_lenght_i) begin//i had to reply 
					next_state = REPLY_PENDING_TRANSACTION;
					ACK_O = 1;
					pending_transaction_executed_o = 0;
					increment_n_of_chunk = 1;
					message_transmitted_o = 0;
					if(n_of_sent_chunk_r<burst_lenght_i-1) begin
						next_data_o = 1;
					end else begin
						next_data_o = 0;
					end
				end else begin
					next_state = IDLE;
					ACK_O = 0;
					pending_transaction_executed_o = 1;
					increment_n_of_chunk = 0;
					message_transmitted_o = 1;
					next_data_o = 0;
				end
			end//REPLY_PENDING_TRANSACTION

			default: begin
				performing_read_o = 0;
				next_state = IDLE;
				next_data_o = 0;
				message_transmitted_o = 0;
				retry_o = 0;
				CYC_O = 0;
				STB_O = 0;
				rst_n_of_ack = 1;
				increment_n_of_ack = 0;
				rst_n_of_chunk = 1;
				increment_n_of_chunk = 0;
				query_o = 0;
				pending_transaction_executed_o = 0;
				ACK_O = 0;
			end//default
		endcase
	end//always

	//state update
	always @(posedge clk) begin
		if(rst) begin
			state <= IDLE;
		end else begin
			state <= next_state;
		end//else if(rst)
	end//always
	//end FSM

	//query_sender_o, query_recipient_o, transaction_type_o, they are registers
	always @(posedge clk) begin
		if(state==IDLE && r_bus_arbitration_i) begin
			query_sender_o <= data_i[`SRC_BITS_HEAD_FLIT];
			query_recipient_o <= data_i[`DEST_BITS_HEAD_FLIT];
			transaction_type_o <= data_i[`CMD_BITS_HEAD_FLIT];
		end//if(state==IDLE && r_bus_arbitration_i)
	end//always

endmodule//wb_master_interface
