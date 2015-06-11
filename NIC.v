////////////////////////////////////////////////////////////////////////////////// 
// 
// Module Name:	NIC 
// Project Name:	NIC_base 
// Description:	Higher module, it contains wb2noc, noc2wb and on_the_fly_node2noc modules
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "wb2noc.v"
`include "noc2wb.v"
`include "on_the_fly_node2noc.v"

module NIC
	#(
	parameter N_TOT_OF_VC						=	`N_OF_VC*`N_OF_VN,
	parameter N_BITS_POINTER_TABLE			=	clog2(`TABLE_PENDING_NODE2NOC_WIDTH),
	parameter N_BITS_FIFO_OUT_BUFFER_ID		=	clog2(`N_FIFO_OUT_BUFFER),
	parameter N_BITS_BURST_LENGHT				=	clog2(`MAX_BURST_LENGHT),
	parameter N_BITS_PACKET_LENGHT			=	clog2(`MAX_PACKET_LENGHT),
	parameter N_BITS_VNET_ID					=	clog2(`N_OF_VN),
	parameter N_BITS_CREDIT						=	clog2(`MAX_CREDIT+1),
	parameter N_BITS_POINTER_MESSAGE_QUEUE	=	clog2(`QUEUE_WIDTH)
	)
	(
	input	clk,
	input	rst,

	//router => NIC
	input			[`FLIT_WIDTH-1:0]					in_link_i,
	input													is_valid_i,
	input			[N_TOT_OF_VC-1:0]					credit_signal_i,
	input			[N_TOT_OF_VC-1:0]					free_signal_i,
	//NIC => router
	output		[`FLIT_WIDTH-1:0]					out_link_o,
	output												is_valid_o,
	output												credit_signal_o,
	output												free_signal_o,
	//NIC(MASTER) => NODE(SLAVE)
	input			[`BUS_DATA_WIDTH-1:0]			DAT_NIC_NODE_I,
	input													ACK_NIC_NODE_I,
	input													RTY_NIC_NODE_I,
	input													ERR_NIC_NODE_I,
	input													STALL_NIC_NODE_I,
	output												CYC_NIC_NODE_O,
	output												STB_NIC_NODE_O,
	output												WE_NIC_NODE_O,
	output		[`BUS_ADDRESS_WIDTH-1:0]		ADR_NIC_NODE_O,
	output		[`BUS_DATA_WIDTH-1:0]			DAT_NIC_NODE_O,
	output		[`BUS_SEL_WIDTH-1:0]				SEL_NIC_NODE_O,
	output		[2:0]									CTI_NIC_NODE_O,
	//NODE(MASTER) => NIC(SLAVE)
	input													CYC_NODE_NIC_I,
	input													STB_NODE_NIC_I,
	input			[2:0]									CTI_NODE_NIC_I,
	input													WE_NODE_NIC_I,
	input			[`BUS_DATA_WIDTH-1:0]			DAT_NODE_NIC_I,
	input			[`BUS_ADDRESS_WIDTH-1:0]		ADR_NODE_NIC_I,
	input			[`BUS_SEL_WIDTH-1:0]				SEL_NODE_NIC_I,
	output		[`BUS_DATA_WIDTH-1:0]			DAT_NODE_NIC_O,
	output												RTY_NODE_NIC_O,
	output												ERR_NODE_NIC_O,
	output												STALL_NODE_NIC_O,
	output												ACK_NODE_NIC_O,
	//WB arbiter
	input													gnt_wb_i
	);

	`include "NIC_utils.vh"

	//signals table - wb2noc
	wire																	new_pending_transaction_wb2noc_table;
	wire				[`N_BIT_SRC_HEAD_FLIT-1:0]					new_sender_wb2noc_table;
	wire				[`N_BIT_DEST_HEAD_FLIT-1:0]				new_recipient_wb2noc_table;
	wire				[`N_BIT_CMD_HEAD_FLIT-1:0]					new_transaction_type_wb2noc_table;

	//signals table - noc2wb
	wire																	query_noc2wb_table;
	wire				[`N_BIT_SRC_HEAD_FLIT-1:0]					query_sender_noc2wb_table;
	wire				[`N_BIT_DEST_HEAD_FLIT-1:0]				query_recipient_noc2wb_table;
	wire				[`N_BIT_CMD_HEAD_FLIT-1:0]					query_transaction_type_noc2wb_table;
	wire																	delete_transaction_noc2wb_table;
	wire																	is_a_pending_transaction_table_noc2wb;

	//dat_o, adr_o, sel_o, ack_o and we_o from noc2wb
	wire										we_o_from_noc2wb;
	wire	[`BUS_ADDRESS_WIDTH-1:0]	adr_o_from_noc2wb;
	wire	[`BUS_DATA_WIDTH-1:0]		dat_o_from_noc2wb;
	wire	[`BUS_SEL_WIDTH-1:0]			sel_o_from_noc2wb;
	wire										ack_o_from_noc2wb;
	assign WE_NIC_NODE_O = we_o_from_noc2wb;
	assign ADR_NIC_NODE_O = adr_o_from_noc2wb;
	assign DAT_NIC_NODE_O = dat_o_from_noc2wb;
	assign SEL_NIC_NODE_O = sel_o_from_noc2wb;
	assign DAT_NODE_NIC_O = dat_o_from_noc2wb;

	//dat_i, adr_i, sel_i and ack_i for wb2noc and ack_o from wb2noc
	wire ack_o_from_wb2noc;

	wire ack_i_for_wb2noc;
	assign ack_i_for_wb2noc = ACK_NIC_NODE_I && !we_o_from_noc2wb;

	wire [`BUS_ADDRESS_WIDTH-1:0] adr_i_for_wb2noc;
	assign adr_i_for_wb2noc = (ACK_NIC_NODE_I) ? adr_o_from_noc2wb : ADR_NODE_NIC_I;

	wire [`BUS_DATA_WIDTH-1:0] dat_i_for_wb2noc;
	assign dat_i_for_wb2noc = (ACK_NIC_NODE_I) ? DAT_NIC_NODE_I : DAT_NODE_NIC_I;

	wire [`BUS_SEL_WIDTH-1:0] sel_i_for_wb2noc;
	assign sel_i_for_wb2noc = (ACK_NIC_NODE_I) ? {`BUS_SEL_WIDTH{1'b1}} : SEL_NODE_NIC_I;

	//ACK_NODE_NIC_O computation
	assign ACK_NODE_NIC_O = ack_o_from_wb2noc || ack_o_from_noc2wb;

	on_the_fly_node2noc
		#(
		.N_BITS_POINTER(N_BITS_POINTER_TABLE)
		)
		on_the_fly_node2noc
		(
		.clk(clk),
		.rst(rst),

		//wb2noc side
		.new_pending_transaction_i(new_pending_transaction_wb2noc_table),
		.new_sender_i(new_sender_wb2noc_table),
		.new_recipient_i(new_recipient_wb2noc_table),
		.new_transaction_type_i(new_transaction_type_wb2noc_table),
		//noc2wb side
		.query_i(query_noc2wb_table),
		.query_sender_i(query_sender_noc2wb_table),
		.query_recipient_i(query_recipient_noc2wb_table),
		.query_transaction_type_i(query_transaction_type_noc2wb_table),
		.delete_transaction_i(delete_transaction_noc2wb_table),
		.is_a_pending_transaction_o(is_a_pending_transaction_table_noc2wb)
		);

	wb2noc
		#(
		.N_TOT_OF_VC(N_TOT_OF_VC),
		.N_BITS_FIFO_OUT_BUFFER_ID(N_BITS_FIFO_OUT_BUFFER_ID),
		.N_BITS_BURST_LENGHT(N_BITS_BURST_LENGHT),
		.N_BITS_PACKET_LENGHT(N_BITS_PACKET_LENGHT),
		.N_BITS_VNET_ID(N_BITS_VNET_ID),
		.N_BITS_CREDIT(N_BITS_CREDIT)
		)
		wb2noc
		(
		.clk(clk),
		.rst(rst),

		//router side
		.credit_signal_i(credit_signal_i),
		.free_signal_i(free_signal_i),
		.out_link_o(out_link_o),
		.is_valid_o(is_valid_o),
		//table side
		.new_pending_transaction_o(new_pending_transaction_wb2noc_table),
		.new_sender_o(new_sender_wb2noc_table),
		.new_recipient_o(new_recipient_wb2noc_table),
		.new_transaction_type_o(new_transaction_type_wb2noc_table),
		//WISHBONE side
		.CYC_I(CYC_NODE_NIC_I),
		.STB_I(STB_NODE_NIC_I),
		.CTI_I(CTI_NODE_NIC_I),
		.WE_I(WE_NODE_NIC_I),
		.DAT_I(dat_i_for_wb2noc),
		.ADR_I(adr_i_for_wb2noc),
		.SEL_I(sel_i_for_wb2noc),
		.ACK_I(ack_i_for_wb2noc),
		.RTY_O(RTY_NODE_NIC_O),
		.ERR_O(ERR_NODE_NIC_O),
		.STALL_O(STALL_NODE_NIC_O),
		.ACK_O(ack_o_from_wb2noc)
		);

	noc2wb
		#(
		.N_BITS_POINTER_FLITS_BUFFER(N_BITS_PACKET_LENGHT),
		.N_BITS_POINTER_MESSAGE_QUEUE(N_BITS_POINTER_MESSAGE_QUEUE),
		.N_BITS_BURST_LENGHT(N_BITS_BURST_LENGHT)
		)
		noc2wb
		(
		.clk(clk),
		.rst(rst),

		//router side
		.in_link_i(in_link_i),
		.is_valid_i(is_valid_i),
		.credit_signal_o(credit_signal_o),
		.free_signal_o(free_signal_o),
		//on the fly table side
		.is_a_pending_transaction_i(is_a_pending_transaction_table_noc2wb),
		.query_o(query_noc2wb_table),
		.pending_transaction_executed_o(delete_transaction_noc2wb_table),
		.query_sender_o(query_sender_noc2wb_table),
		.query_recipient_o(query_recipient_noc2wb_table),
		.transaction_type_o(query_transaction_type_noc2wb_table),
		//WISHBONE BUS signals
		.ACK_I(ACK_NIC_NODE_I),
		.RTY_I(RTY_NIC_NODE_I),
		.ERR_I(ERR_NIC_NODE_I),
		.STALL_I(STALL_NIC_NODE_I),
		.CYC_O(CYC_NIC_NODE_O),
		.STB_O(STB_NIC_NODE_O),
		.WE_O(we_o_from_noc2wb),
		.ADR_O(adr_o_from_noc2wb),
		.DAT_O(dat_o_from_noc2wb),
		.SEL_O(sel_o_from_noc2wb),
		.CTI_O(CTI_NIC_NODE_O),
		.ACK_O(ack_o_from_noc2wb),
		.gnt_wb_i(gnt_wb_i)
		);

endmodule//NIC
