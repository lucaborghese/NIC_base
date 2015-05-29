`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_NoC2WB 
// Project Name:	NIC_base 
// Description:	Testbench of the entire line: Router -> Flits_buffer -> message_queue -> wb_master_interface -> WB
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "flits_buffer.v"
`include "message_queue.v"
`include "wb_master_interface.v"
`include "fake_slave_pipeline_noBurst.v"

module testbench_NoC2WB
	#(
	parameter	N_BITS_POINTER_FLITS_BUFFER	=	clog2(`MAX_PACKET_LENGHT),
	parameter	N_BITS_POINTER_MESSAGE_QUEUE	=	clog2(`QUEUE_WIDTH),
	parameter	N_BITS_BURST_LENGHT				=	clog2(`MAX_BURST_LENGHT + 1)
	)
	();

	`include "NIC_utils.vh"

	reg	clk;
	reg	rst;

	//clock
	always #5 clk = ~clk;

	//signal Router -> flits_buffer
	reg	[`FLIT_WIDTH-1:0]	in_link_i;
	reg							is_valid_i;

	//signal flits_buffer -> Router
	wire	credit_signal_o;
	wire	free_signal_o;

	//signal queue_message -> flits_buffer
	wire	g_pkt_to_msg;

	//signal flits_buffer -> queue_message
	wire														r_pkt_to_msg;
	wire	[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	out_link;
	wire	[`MAX_PACKET_LENGHT-1:0]					out_sel;

	//signal queue_message -> wb_master_interface
	wire														r_bus_arbitration;
	wire	[`BUS_ADDRESS_WIDTH-1:0]					address;
	wire	[`BUS_DATA_WIDTH-1:0]						data;
	wire	[(`BUS_DATA_WIDTH/`GRANULARITY)-1:0]	sel;
	wire														transaction_type;
	wire	[N_BITS_BURST_LENGHT-1:0]					burst_lenght;

	//signal wb_master_interface -> queue_message
	wire	next_data;
	wire	retry;
	wire	message_transmitted;

	//signal wb_fake_slave -> wb_master_interface
	wire	[`BUS_DATA_WIDTH-1:0]	DAT_SLAVE_MASTER;
	wire									ACK_NODE_NIC;
	wire									RTY_IO;
	wire									ERR_IO;
	wire									STALL_IO;

	//signal wb_master_interface -> wb_fake_slave
	wire														CYC_IO;
	wire														STB_IO;
	wire														WE_IO;
	wire	[`BUS_ADDRESS_WIDTH-1:0]					ADR_IO;
	wire	[`BUS_DATA_WIDTH-1:0]						DAT_MASTER_SLAVE;
	wire	[(`BUS_DATA_WIDTH/`GRANULARITY)-1:0]	SEL_IO;
	wire	[2:0]												CTI_IO;

	//signal wb_master_interface -> wb_fake_master
	wire	ACK_NIC_NODE;
	
	//signal wb_arbiter(fake_slave) -> wb_master_interface
	wire	gnt_wb;

	flits_buffer
		#(
		.N_BITS_POINTER(N_BITS_POINTER_FLITS_BUFFER)
		)
		buffer
		(
		.clk(clk),
		.rst(rst),

		//input from Router
		.in_link_i(in_link_i),
		.is_valid_i(is_valid_i),
		//output for Router
		.credit_signal_o(credit_signal_o),
		.free_signal_o(free_signal_o),

		//input from queue_message
		.g_pkt_to_msg_i(g_pkt_to_msg),
		//output for queue_message
		.r_pkt_to_msg_o(r_pkt_to_msg),
		.out_link_o(out_link),
		.out_sel_o(out_sel)
		);

	message_queue
		#(
		.N_BITS_POINTER(N_BITS_POINTER_MESSAGE_QUEUE),
		.N_BITS_BURST_LENGHT(N_BITS_BURST_LENGHT)
		)
		queue
		(
		.clk(clk),
		.rst(rst),

		//input from flits_buffer
		.in_link_i(out_link),
		.in_sel_i(out_sel),
		.r_pkt_to_msg_i(r_pkt_to_msg),
		//output for flits_buffer
		.g_pkt_to_msg_o(g_pkt_to_msg),

		//input from wb_master_interface
		.next_data_i(next_data),
		.retry_i(retry),
		.message_transmitted_i(message_transmitted),
		//output for wb_master_interface
		.r_bus_arbitration_o(r_bus_arbitration),
		.address_o(address),
		.data_o(data),
		.sel_o(sel),
		.transaction_type_o(transaction_type),
		.burst_lenght_o(burst_lenght)
		);

	wb_master_interface
		#(
		.N_BITS_BURST_LENGHT(N_BITS_BURST_LENGHT)
		)
		master
		(
		.clk(clk),
		.rst(rst),

		//input from queue_message
		.r_bus_arbitration_i(r_bus_arbitration),
		.address_i(address),
		.data_i(data),
		.sel_i(sel),
		.transaction_type_i(transaction_type),
		.burst_lenght_i(burst_lenght),
		//output for queue_message
		.next_data_o(next_data),
		.message_transmitted_o(message_transmitted),
		.retry_o(retry),

		//input from WB(fake_slave)
		.DAT_I(DAT_SLAVE_MASTER),
		.ACK_I(ACK_NODE_NIC),
		.RTY_I(RTY_IO),
		.ERR_I(ERR_IO),
		.STALL_I(STALL_IO),
		//output for WB(fake_slave)
		.CYC_O(CYC_IO),
		.STB_O(STB_IO),
		.ACK_O(ACK_NIC_NODE),
		.WE_O(WE_IO),
		.ADR_O(ADR_IO),
		.DAT_O(DAT_MASTER_SLAVE),
		.SEL_O(SEL_IO),
		.CTI_O(CTI_IO),
		//input from WB arbiter(fake_slave)
		.gnt_wb_i(gnt_wb)
		);

	fake_slave_pipeline_noBurst fake_slave
		(
		.clk(clk),

		//input from wb_master_interface
		.CYC_I(CYC_IO),
		.STB_I(STB_IO),
		.WE_I(WE_IO),
		.ADR_I(ADR_IO),
		.DAT_I(DAT_MASTER_SLAVE),
		.SEL_I(SEL_IO),
		.CTI_I(CTI_IO),
		//output for wb_master_interface
		.DAT_O(DAT_SLAVE_MASTER),
		.ACK_O(ACK_IO),
		.RTY_O(RTY_IO),
		.ERR_O(ERR_IO),
		.STALL_O(STALL_IO),
		.gnt_wb_o(gnt_wb)
		);

	//first number: 0 head/write(non so se possa mai servire), 4 head/write, 1 body, 2 tail, 3 head_tail/read 
	initial begin
		clk = 1;
		rst = 1;
		in_link_i = 0;
		is_valid_i = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		is_valid_i = 1;
		in_link_i = `FLIT_WIDTH'h4;
		@(posedge clk);
		in_link_i = `FLIT_WIDTH'hA1;
		@(posedge clk);
		in_link_i = `FLIT_WIDTH'hB1;
		@(posedge clk);
		in_link_i = `FLIT_WIDTH'hC1;
		@(posedge clk);
		in_link_i = `FLIT_WIDTH'hD2;
		@(posedge clk);
		is_valid_i = 0;
		@(posedge clk);
		@(posedge clk);
		is_valid_i = 1;
		in_link_i = `FLIT_WIDTH'hF3;
		@(posedge clk);
		is_valid_i = 0;
		repeat(20) @(posedge clk);
		$finish;
	end

endmodule//testbench_NoC2WB
