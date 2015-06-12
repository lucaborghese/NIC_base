//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	noc2wb 
// Project Name:	NIC_base
// Description:	Module that cover the path: router => flits_buffer => message_queue => wb_master_interface => WB bus
//						It contains flits_buffer, message_queue and wb_master_interface modules
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "input_port.v"
`include "message_queue.v"
`include "wb_master_interface.v"

module noc2wb
	#(
	parameter	N_BITS_POINTER_FLITS_BUFFER	=	5,//clog2(`MAX_PACKET_LENGHT)
	parameter	N_BITS_POINTER_MESSAGE_QUEUE	=	5,//clog2(`QUEUE_WIDTH)
	parameter	N_BITS_BURST_LENGHT				=	5,//clog2(`MAX_BURST_LENGHT + 1)
	parameter	N_TOT_OF_VC							=	4,
	parameter	N_BITS_POINTER_INPUT_PORT		=	3//clog2(N_TOT_OF_VC)
	)
	(
	input	clk,
	input	rst,

	//Router side
	input			[`FLIT_WIDTH-1:0]								in_link_i,//data link from NoC's router
	input																is_valid_i,//high if there is a valid flit in in_link_i
	output		[N_TOT_OF_VC-1:0]								credit_signal_o,//high if one flit buffer is emptied in this cycle, low otherwise. In this implementation it is not well used, it works only if buffer_r can contain an entire packet
	output		[N_TOT_OF_VC-1:0]								free_signal_o,//high if buffer_r change state from busy to idle

	//on the fly table side
	input																is_a_pending_transaction_i,//reply from the table, high if the message is a reply for a node
	output															query_o,//high if we are querying the table
	output															pending_transaction_executed_o,//high if the reply has been executed and we receive the ack
	output		[`N_BIT_SRC_HEAD_FLIT-1:0]					query_sender_o,//local node that begin the transaction(PROBABLY NOT ALL THE BIT IN THE ADDRESS ARE USEFULL) 
	output		[`N_BIT_DEST_HEAD_FLIT-1:0]				query_recipient_o,//remote node that generate the reply
	output		[`N_BIT_CMD_HEAD_FLIT-1:0]					transaction_type_o,
	
	//WISHBONE BUS signals
//	input			[`BUS_DATA_WIDTH-1:0]						DAT_I,//can be eliminated
	input																ACK_I,
	input																RTY_I,
	input																ERR_I,
	input																STALL_I,
	output															CYC_O,
	output															STB_O,
	output															WE_O,
	output		[`BUS_ADDRESS_WIDTH-1:0]					ADR_O,
	output		[`BUS_DATA_WIDTH-1:0]						DAT_O,
	output		[(`BUS_DATA_WIDTH/`GRANULARITY)-1:0]	SEL_O,
	output		[2:0]												CTI_O,
	output															ACK_O,//this isn't a signal of the master, it is used in the pipeline implementation of this NiC when this module reply for the wb_slave_interface

	//WISHBONE arbiter signal
	input																gnt_wb_i
	);

	//signals flits_buffer - message_queue
	wire														g_pkt_to_msg_mq_ip;
	wire														r_pkt_to_msg_ip_mq;
	wire	[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	out_link_ip_mq;
//	wire	[N_BITS_POINTER_FLITS_BUFFER-1:0]		head_pointer_ip_mq;
//	wire	[`MAX_PACKET_LENGHT-1:0]					out_sel_ip_mq;

	//signals message_queue - wb_master_interface
	wire										r_bus_arbitration_mq_wm;
	wire	[`BUS_ADDRESS_WIDTH-1:0]	address_mq_wm;
	wire	[`BUS_DATA_WIDTH-1:0]		data_mq_wm;
	wire	[`BUS_SEL_WIDTH-1:0]			sel_mq_wm;
	wire										transaction_type_mq_wm;
	wire	[N_BITS_BURST_LENGHT-1:0]	burst_lenght_mq_wm;
	wire										next_data_wm_mq;
	wire										retry_wm_mq;
	wire										message_transmitted_wm_mq;

	input_port
		#(
		.N_TOT_OF_VC(N_TOT_OF_VC),
		.N_BITS_POINTER_FLITS_BUFFER(N_BITS_POINTER_FLITS_BUFFER),
		.N_BITS_POINTER(N_BITS_POINTER_INPUT_PORT)
		)
		input_port
		(
		.clk(clk),
		.rst(rst),

		//router side
		.in_link_i(in_link_i),
		.is_valid_i(is_valid_i),
		.credit_signal_o(credit_signal_o),
		.free_signal_o(free_signal_o),
		//queue side
		.g_pkt_to_msg_i(g_pkt_to_msg_mq_ip),
		.r_pkt_to_msg_o(r_pkt_to_msg_ip_mq),
		.out_link_o(out_link_ip_mq)
//		.head_pointer_o(head_pointer_ip_mq),
//		.out_sel_o(out_sel_ip_mq)
		);

	message_queue
		#(
		.N_BITS_POINTER(N_BITS_POINTER_MESSAGE_QUEUE),
		.N_BITS_BURST_LENGHT(N_BITS_BURST_LENGHT)
		)
		message_queue
		(
		.clk(clk),
		.rst(rst),

		//flits_buffer side
		.in_link_i(out_link_ip_mq),
//		.in_sel_i(out_sel_ip_mq),
		.r_pkt_to_msg_i(r_pkt_to_msg_ip_mq),
		.g_pkt_to_msg_o(g_pkt_to_msg_mq_ip),
		//wb_master_interface side
		.r_bus_arbitration_o(r_bus_arbitration_mq_wm),
		.address_o(address_mq_wm),
		.data_o(data_mq_wm),
		.sel_o(sel_mq_wm),
		.transaction_type_o(transaction_type_mq_wm),
		.burst_lenght_o(burst_lenght_mq_wm),
		.next_data_i(next_data_wm_mq),
		.retry_i(retry_wm_mq),
		.message_transmitted_i(message_transmitted_wm_mq)
		);

	wb_master_interface
		#(
		.N_BITS_BURST_LENGHT(N_BITS_BURST_LENGHT)
		)
		wb_master_interface
		(
		.clk(clk),
		.rst(rst),

		//message_queue side
		.r_bus_arbitration_i(r_bus_arbitration_mq_wm),
		.address_i(address_mq_wm),
		.data_i(data_mq_wm),
		.sel_i(sel_mq_wm),
		.transaction_type_i(transaction_type_mq_wm),
		.burst_lenght_i(burst_lenght_mq_wm),
		.next_data_o(next_data_wm_mq),
		.message_transmitted_o(message_transmitted_wm_mq),
		.retry_o(retry_wm_mq),
		//on the fly table side
		.is_a_pending_transaction_i(is_a_pending_transaction_i),
		.query_o(query_o),
		.pending_transaction_executed_o(pending_transaction_executed_o),
		.query_sender_o(query_sender_o),
		.query_recipient_o(query_recipient_o),
		.transaction_type_o(transaction_type_o),
		//WB bus side
		.ACK_I(ACK_I),
		.RTY_I(RTY_I),
		.ERR_I(ERR_I),
		.STALL_I(STALL_I),
		.CYC_O(CYC_O),
		.STB_O(STB_O),
		.WE_O(WE_O),
		.ADR_O(ADR_O),
		.DAT_O(DAT_O),
		.SEL_O(SEL_O),
		.CTI_O(CTI_O),
		.ACK_O(ACK_O),
		//arbiter side
		.gnt_wb_i(gnt_wb_i)
		);

endmodule//noc2wb
