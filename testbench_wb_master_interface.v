`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_wb_master_interface 
// Project Name:	NIC_base
// Description:	Testbench for wb_master_interface
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "wb_master_interface.v"
`include "fake_slave_pipeline_noBurst.v"

module testbench_wb_master_interface
	#(
	parameter	N_BITS_BURST_LENGHT	=	clog2(`MAX_BURST_LENGHT+1)
	)
	();

	`include "NIC_utils.vh"

	reg	clk;
	reg	rst;

	//clock
	always #5 clk = ~clk;

	//Wb_master_interface signal
	//input queue side
	reg														r_bus_arbitration_i;
	reg	[`BUS_ADDRESS_WIDTH-1:0]					address_i;
	reg	[`BUS_TGA_WIDTH-1:0]							tga_i;
	reg	[`BUS_TGC_WIDTH-1:0]							tgc_i;
	reg	[`BUS_DATA_WIDTH-1:0]						data_i;
	reg	[(`BUS_DATA_WIDTH/`GRANULARITY)-1:0]	sel_i;
	reg														transaction_type_i;
	reg	[N_BITS_BURST_LENGHT-1:0]					burst_lenght_i;

	//input table side
	reg													is_a_pending_transaction_i;

	//output table side
	wire																query_o;//high if we are querying the table
	wire																pending_transaction_executed_o;//high if the reply has been executed and we receive the ack
	wire			[`N_BIT_SRC_HEAD_FLIT-1:0]					query_sender_o;//local node that begin the transaction(PROBABLY NOT ALL THE BIT IN THE ADDRESS ARE USEFULL) 
	wire			[`N_BIT_DEST_HEAD_FLIT-1:0]				query_recipient_o;//remote node that generate the reply
	wire			[`N_BIT_CMD_HEAD_FLIT-1:0]					transaction_type_o;

	//output queue side
	wire														next_data_o;
	wire														message_transmitted_o;
	wire														retry_o;

	//input WISHBONE bus
	wire	[`BUS_DATA_WIDTH-1:0]						DAT_I;
	wire														ACK_I;
	wire														RTY_I;
	wire														ERR_I;
	wire														STALL_I;

	//output WISHBONE bus
	wire														CYC_O;
	wire														STB_O;
	wire														WE_O;
	wire	[`BUS_ADDRESS_WIDTH-1:0]					ADR_O;
	wire	[`BUS_DATA_WIDTH-1:0]						DAT_O;
	wire	[(`BUS_DATA_WIDTH/`GRANULARITY)-1:0]	SEL_O;
	wire	[2:0]												CTI_O;
	wire														ACK_O;

	//STALL_O from fake_slave
	wire STALL_O;
	assign STALL_I = (gnt_wb) ? STALL_O : 1'b1;

	//I/O arbiter
	wire														gnt_wb;

	wb_master_interface
		#(
		.N_BITS_BURST_LENGHT(N_BITS_BURST_LENGHT)
		)
		master
		(
		.clk(clk),
		.rst(rst),

		//input queue side
		.r_bus_arbitration_i(r_bus_arbitration_i),
		.address_i(address_i),
		.tga_i(tga_i),
		.tgc_i(tgc_i),
		.data_i(data_i),
		.sel_i(sel_i),
		.transaction_type_i(transaction_type_i),
		.burst_lenght_i(burst_lenght_i),
		//output queue side
		.next_data_o(next_data_o),
		.message_transmitted_o(message_transmitted_o),
		.retry_o(retry_o),
		//input table side
		.is_a_pending_transaction_i(is_a_pending_transaction_i),
		//output table side
		.query_o(query_o),
		.pending_transaction_executed_o(pending_transaction_executed_o),
		.query_sender_o(query_sender_o),
		.query_recipient_o(query_recipient_o),
		.transaction_type_o(transaction_type_o),
		//input WISHBONE bus
//		.DAT_I(DAT_I),
		.ACK_I(ACK_I),
		.RTY_I(RTY_I),
		.ERR_I(ERR_I),
		.STALL_I(STALL_I),
		//output WISHBONE bus
		.CYC_O(CYC_O),
		.STB_O(STB_O),
		.ACK_O(ACK_O),
		.WE_O(WE_O),
		.ADR_O(ADR_O),
		.DAT_O(DAT_O),
		.SEL_O(SEL_O),
		.CTI_O(CTI_O),
		//I/O arbiter
		.gnt_wb_i(gnt_wb)
		);

	fake_slave_pipeline_noBurst fake_slave
		(
		.clk(clk),

		//input
		.CYC_I(CYC_O),
		.STB_I(STB_O),
		.WE_I(WE_O),
		.ADR_I(ADR_O),
		.DAT_I(DAT_O),
		.SEL_I(SEL_O),
		.CTI_I(CTI_O),

		//output
		.gnt_wb_o(gnt_wb),
		.DAT_O(DAT_I),
		.ACK_O(ACK_I),
		.RTY_O(RTY_I),
		.ERR_O(ERR_I),
		.STALL_O(STALL_O)
		);

	initial begin
		clk = 0;
		rst = 1;
		address_i = $random;
		tga_i = $random;
		tgc_i = $random;
		data_i = $random;
		sel_i = ~0;
		is_a_pending_transaction_i = 0;
		r_bus_arbitration_i = 0;
		transaction_type_i = 1;
		burst_lenght_i = 0;
		repeat(2) @(posedge clk);
		#1 rst = 0;
		@(posedge clk);
		r_bus_arbitration_i = 1;
		burst_lenght_i = 5;
		@(posedge clk);
		repeat(20) @(posedge clk);
		$finish;
	end//initial

endmodule//testbench_wb_master_interface
