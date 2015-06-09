`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Module Name:	testbench_WB2NoC 
// Project Name:	NIC_base
// Description:	testbench of the line WB => NoC
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "fifo_nic2noc.v"
`include "link_allocator.v"
`include "vc_allocator.v"
`include "wb_slave_interface.v"

module testbench_WB2NoC
	#(
	parameter N_TOT_OF_VC					=	`N_OF_VC*`N_OF_VN,
	parameter N_BITS_FIFO_OUT_BUFFER_ID	=	clog2(`N_FIFO_OUT_BUFFER),
	parameter N_BITS_BURST_LENGHT			=	clog2(`MAX_BURST_LENGHT),
	parameter N_BITS_PACKET_LENGHT		=	clog2(`MAX_PACKET_LENGHT),
	parameter N_BITS_VNET_ID				=	clog2(`N_OF_VN),
	parameter N_BITS_CREDIT					=	clog2(`MAX_CREDIT+1)
	)
	();

	`include "NIC_utils.vh"

	reg clk;
	reg rst;

	//clock
	always #5 clk=~clk;

	//signal router - fifo_nic2noc
	reg	[N_TOT_OF_VC-1:0]	credit_signal_i;
	reg	[N_TOT_OF_VC-1:0]	free_signal_i;
	wire	[`FLIT_WIDTH-1:0]	out_link_o;
	wire							is_valid_o; 

	//signal fifo_nic2noc - wb_slave_iterface
	wire	[N_TOT_OF_VC-1:0]										g_fifo_pointer;//the i-th vc has been allocated from VA
	wire	[N_TOT_OF_VC*N_BITS_FIFO_OUT_BUFFER_ID-1:0]	g_fifo_out_buffer_id;//which fifo_out_buffer has been allocated for the i-th pointer
	wire	[N_TOT_OF_VC-1:0]										release_pointer;//if the i-th bit is high the i-th pointer will pass from busy to idle
	wire	[N_TOT_OF_VC-1:0]										credit_signal;//high if the i-th vc return a credit
	wire	[N_TOT_OF_VC*N_BITS_FIFO_OUT_BUFFER_ID-1:0]	fifo_pointed;//which fifo must obtain the credit
	wire	[`FLIT_WIDTH-1:0]										in_link;
	wire																is_valid;

	//signal vc_allocator - fifo_nic2noc
	wire	[N_TOT_OF_VC-1:0]	fifo_pointer_state;

	//signal wb_slave_interface - link_allocator
	wire	[`N_FIFO_OUT_BUFFER-1:0]			r_la;
	wire												g_la;
	wire	[N_BITS_FIFO_OUT_BUFFER_ID-1:0]	g_la_channel_id;

	//signals vc_allocator - wb_slave_interface
	wire	[`N_FIFO_OUT_BUFFER-1:0]					r_va;//if r_va_i[i] is high, the i-th fifo out buffer require VA stage
	wire	[`N_FIFO_OUT_BUFFER*N_TOT_OF_VC-1:0]	r_va_vc_requested;//vc that the fifo_out_buffer requires
	wire	[`N_FIFO_OUT_BUFFER-1:0]					g_va;
	wire	[`N_FIFO_OUT_BUFFER*N_TOT_OF_VC-1:0]	g_va_vc_id;//one-hot encoding for every request

	//signals on_the_fly_node2noc - wb_slave_interface
	wire											new_pending_transaction_o;//high if the new_* signals are valid
	wire	[`N_BIT_SRC_HEAD_FLIT-1:0]		new_sender_o;//sender of the new pending transaction
	wire	[`N_BIT_DEST_HEAD_FLIT-1:0]	new_recipient_o;//recipient of the new pending transaction
	wire	[`N_BIT_CMD_HEAD_FLIT-1:0]		new_transaction_type_o;//type of the new pending transaction

	//signalse wb_slave_interface - WISHBONE bus
	reg										CYC_I;
	reg										STB_I;
	reg	[2:0]								CTI_I;
	reg										WE_I;
	reg	[`BUS_DATA_WIDTH-1:0]		DAT_I;
	reg	[`BUS_ADDRESS_WIDTH-1:0]	ADR_I;
	reg	[`BUS_SEL_WIDTH-1:0]			SEL_I;
	reg										ACK_I;
	wire										RTY_O;
	wire										ERR_O;
	wire										STALL_O;
	wire										ACK_O;

	fifo_nic2noc
		#(
		.N_TOT_OF_VC(N_TOT_OF_VC),
		.N_BITS_POINTER(N_BITS_FIFO_OUT_BUFFER_ID)
		)
		fifo_nic2noc
		(
		.clk(clk),
		.rst(rst),

		//signals router side
		.credit_signal_i(credit_signal_i),
		.free_signal_i(free_signal_i),
		.out_link_o(out_link_o),
		.is_valid_o(is_valid_o),
		//signals wb_slave_interface side
		.g_fifo_pointer_i(g_fifo_pointer),
		.g_fifo_out_buffer_id_i(g_fifo_out_buffer_id),
		.release_pointer_i(release_pointer),
		.credit_signal_o(credit_signal),
		.fifo_pointed_o(fifo_pointed),
		.in_link_i(in_link),
		.is_valid_i(is_valid),
		//signal vc_allocator side
		.fifo_pointer_state_o(fifo_pointer_state)
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

		//signals wb_slave_interface side
		.r_la_i(r_la),
		.g_la_o(g_la),
		.g_channel_id_o(g_la_channel_id)
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

		//signals wb_slave_interface side
		.r_va_i(r_va),
		.r_vc_requested_i(r_va_vc_requested),
		.g_va_o(g_va),
		.g_vc_id_o(g_va_vc_id),
		//signal fifo_nic2noc side
		.fifo_pointer_state_i(fifo_pointer_state)
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

		//signals on_the_fly table side
		.new_pending_transaction_o(new_pending_transaction_o),
		.new_sender_o(new_sender_o),
		.new_recipient_o(new_recipient_o),
		.new_transaction_type_o(new_transaction_type_o),
		//signals link_allocator side
		.r_la_o(r_la),
		.g_la_i(g_la),
		.g_la_fifo_out_buffer_id_i(g_la_channel_id),
		//signals vc_allocator side
		.r_va_o(r_va),
		.r_vc_requested_o(r_va_vc_requested),
		.g_va_i(g_va),
		.g_va_vc_id_i(g_va_vc_id),
		//signals WISHBONE bus side
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
		//signals fifo_nic2noc side
		.g_fifo_pointer_o(g_fifo_pointer),
		.g_fifo_out_buffer_id_o(g_fifo_out_buffer_id),
		.release_pointer_o(release_pointer),
		.credit_signal_i(credit_signal),
		.fifo_pointed_i(fifo_pointed),
		.out_link_o(in_link),
		.is_valid_o(is_valid)
		);

	initial begin
		clk = 0;
		rst = 1;
		credit_signal_i = 0;
		free_signal_i = 0;
		CYC_I = 0;
		STB_I = 0;
		CTI_I = 0;
		WE_I = 1;
		DAT_I = 0;
		ADR_I = 0;
		SEL_I = ~0;
		ACK_I = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		CYC_I = 1;
		STB_I = 1;
		DAT_I = 32'hBBB10000;
		@(posedge clk);
		DAT_I	= 32'hDDD1CCC1;
		@(posedge clk);
		DAT_I = 32'h0000FFF2;
		@(posedge clk);
		STB_I = 0;
		@(posedge clk);
		CYC_I = 0;
		repeat(10) @(posedge clk);
		$finish;
	end//initial

endmodule//testbench_WB2NoC
