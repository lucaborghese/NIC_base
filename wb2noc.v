//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	wb2noc 
// Project Name:	NIC_base
// Description:	Module that cover the path: router <= fifo_nic2noc <= wb_slave_interface <= WB bus
//						It contains fifo_nic2noc, wb_slave_interface, link_allocator and vc_allocator modules
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "fifo_nic2noc.v"
`include "link_allocator.v"
`include "vc_allocator.v"
`include "wb_slave_interface.v"

module wb2noc
	#(
	parameter N_TOT_OF_VC					=	6,//`N_OF_VC*`N_OF_VN
	parameter N_BITS_FIFO_OUT_BUFFER_ID	=	5,//clog2(`N_FIFO_OUT_BUFFER)
	parameter N_BITS_BURST_LENGHT			=	5,//clog2(`MAX_BURST_LENGHT)
	parameter N_BITS_PACKET_LENGHT		=	5,//clog2(`MAX_PACKET_LENGHT)
	parameter N_BITS_VNET_ID				=	2,//clog2(`N_OF_VN)
	parameter N_BITS_CREDIT					=	4//clog2(`MAX_CREDIT+1)
	)
	(
	input	clk,
	input	rst,

	//NoC side
	input		[N_TOT_OF_VC-1:0]					credit_signal_i,
	input		[N_TOT_OF_VC-1:0]					free_signal_i,
	output	[`FLIT_WIDTH-1:0]					out_link_o,
	output											is_valid_o,

	//on_the_fly_node2noc table side
	output											new_pending_transaction_o,//high if the new_* signals are valid
	output	[`N_BIT_SRC_HEAD_FLIT-1:0]		new_sender_o,//sender of the new pending transaction
	output	[`N_BIT_DEST_HEAD_FLIT-1:0]	new_recipient_o,//recipient of the new pending transaction
	output	[`N_BIT_CMD_HEAD_FLIT-1:0]		new_transaction_type_o,//type of the new pending transaction
	
	//WISHBONE bus side
	input												CYC_I,
	input												STB_I,
	input		[2:0]									CTI_I,
	input												WE_I,
	input		[`BUS_DATA_WIDTH-1:0]			DAT_I,
	input		[`BUS_ADDRESS_WIDTH-1:0]		ADR_I,
	input		[`BUS_SEL_WIDTH-1:0]				SEL_I,
	input												ACK_I,
	output											RTY_O,
	output											ERR_O,
	output											STALL_O,
	output											ACK_O
	);

	//signals fifo_nic2noc - wb_slave_interface
	wire	[N_TOT_OF_VC-1:0]										g_fifo_pointer_wb_fifo;//the i-th vc has been allocated from VA
	wire	[N_TOT_OF_VC*N_BITS_FIFO_OUT_BUFFER_ID-1:0]	g_fifo_out_buffer_id_wb_fifo;//which fifo_out_buffer has been allocated for the i-th pointer
	wire	[N_TOT_OF_VC-1:0]										release_pointer_wb_fifo;//if the i-th bit is high the i-th pointer will pass from busy to idle
	wire	[N_TOT_OF_VC-1:0]										credit_signal_fifo_wb;//high if the i-th vc return a credit
	wire	[N_TOT_OF_VC*N_BITS_FIFO_OUT_BUFFER_ID-1:0]	fifo_pointed_fifo_wb;//which fifo must obtain the credit
	wire	[`FLIT_WIDTH-1:0]										in_link_wb_fifo;
	wire																is_valid_wb_fifo;

	//signal fifo_nic2noc - vc_allocator
	wire	[N_TOT_OF_VC-1:0]	fifo_pointer_state_fifo_va;

	//signals link_allocator - wb_slave_interface
	wire	[`N_FIFO_OUT_BUFFER-1:0]			r_la_wb_la;
	wire												g_la_la_wb;
	wire	[N_BITS_FIFO_OUT_BUFFER_ID-1:0]	g_la_channel_id_la_wb;

	//signals vc_allocator - wb_slave_interface
	wire	[`N_FIFO_OUT_BUFFER-1:0]					r_va_wb_vc;//if r_va_i[i] is high, the i-th fifo out buffer require VA stage
	wire	[`N_FIFO_OUT_BUFFER*N_TOT_OF_VC-1:0]	r_va_vc_requested_wb_vc;//vc that the fifo_out_buffer requires
	wire	[`N_FIFO_OUT_BUFFER-1:0]					g_va_vc_wb;
	wire	[`N_FIFO_OUT_BUFFER*N_TOT_OF_VC-1:0]	g_va_vc_id_vc_wb;//one-hot encoding for every request

	fifo_nic2noc
		#(
		.N_TOT_OF_VC(N_TOT_OF_VC),
		.N_BITS_POINTER(N_BITS_FIFO_OUT_BUFFER_ID)
		)
		fifo_nic2noc
		(
		.clk(clk),
		.rst(rst),

		//router side
		.credit_signal_i(credit_signal_i),
		.free_signal_i(free_signal_i),
		.out_link_o(out_link_o),
		.is_valid_o(is_valid_o),
		//wb_master_interface side
		.g_fifo_pointer_i(g_fifo_pointer_wb_fifo),
		.g_fifo_out_buffer_id_i(g_fifo_out_buffer_id_wb_fifo),
		.release_pointer_i(release_pointer_wb_fifo),
		.credit_signal_o(credit_signal_fifo_wb),
		.fifo_pointed_o(fifo_pointed_fifo_wb),
		.in_link_i(in_link_wb_fifo),
		.is_valid_i(is_valid_wb_fifo),
		//vc_allocator side
		.fifo_pointer_state_o(fifo_pointer_state_fifo_va)
		);

	link_allocator
		#(
		.N_REQUEST_SIGNAL(`N_FIFO_OUT_BUFFER),
		.N_BITS_POINTER(N_BITS_FIFO_OUT_BUFFER_ID)
		)
		link_allocator
		(
		.clk(clk),
		.rst(rst),

		//wb_slave_interface side
		.r_la_i(r_la_wb_la),
		.g_la_o(g_la_la_wb),
		.g_channel_id_o(g_la_channel_id_la_wb)
		);

	vc_allocator
		#(
		.N_OF_REQUEST(`N_FIFO_OUT_BUFFER),
		.N_BITS_N_OF_REQUEST(N_BITS_FIFO_OUT_BUFFER_ID),
		.N_OF_VN(`N_OF_VN),
		.N_OF_VC(`N_OF_VC),
		.N_TOT_OF_VC(N_TOT_OF_VC)
		)
		vc_allocator
		(
		.clk(clk),
		.rst(rst),

		//wb_slave_interface side
		.r_va_i(r_va_wb_vc),
		.r_vc_requested_i(r_va_vc_requested_wb_vc),
		.g_va_o(g_va_vc_wb),
		.g_vc_id_o(g_va_vc_id_vc_wb),
		//fifo_nic2noc side
		.fifo_pointer_state_i(fifo_pointer_state_fifo_va)
		);

	wb_slave_interface
		#(
		.N_BITS_BURST_LENGHT(N_BITS_BURST_LENGHT),
		.N_BITS_PACKET_LENGHT(N_BITS_PACKET_LENGHT),
		.N_FIFO_OUT_BUFFER(`N_FIFO_OUT_BUFFER),
		.N_BITS_FIFO_OUT_BUFFER(N_BITS_FIFO_OUT_BUFFER_ID),
		.N_BITS_VNET_ID(N_BITS_VNET_ID),
		.N_TOT_OF_VC(N_TOT_OF_VC),
		.N_BITS_CREDIT(N_BITS_CREDIT)
		)
		wb_slave_interface
		(
		.clk(clk),
		.rst(rst),

		//table side
		.new_pending_transaction_o(new_pending_transaction_o),
		.new_sender_o(new_sender_o),
		.new_recipient_o(new_recipient_o),
		.new_transaction_type_o(new_transaction_type_o),
		//link_allocator side
		.r_la_o(r_la_wb_la),
		.g_la_i(g_la_la_wb),
		.g_la_fifo_out_buffer_id_i(g_la_channel_id_la_wb),
		//vc_allocator side
		.r_va_o(r_va_wb_vc),
		.r_vc_requested_o(r_va_vc_requested_wb_vc),
		.g_va_i(g_va_vc_wb),
		.g_va_vc_id_i(g_va_vc_id_vc_wb),
		//WISHBONE BUS side
		.CYC_I(CYC_I),
		.STB_I(STB_I),
		.CTI_I(CTI_I),
		.WE_I(WE_I),
		.DAT_I(DAT_I),
		.ADR_I(ADR_I),
		.SEL_I(SEL_I),
		.ACK_I(ACK_I),
		.RTY_O(RTY_O),
		.ERR_O(ERR_O),
		.STALL_O(STALL_O),
		.ACK_O(ACK_O),
		//fifo_nic2noc side
		.g_fifo_pointer_o(g_fifo_pointer_wb_fifo),
		.g_fifo_out_buffer_id_o(g_fifo_out_buffer_id_wb_fifo),
		.release_pointer_o(release_pointer_wb_fifo),
		.credit_signal_i(credit_signal_fifo_wb),
		.fifo_pointed_i(fifo_pointed_fifo_wb),
		.out_link_o(in_link_wb_fifo),
		.is_valid_o(is_valid_wb_fifo)
		);

endmodule//wb2noc
