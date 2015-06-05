`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_on_the_fly 
// Project Name:	NIC_base
// Description:	Testbench of on_the_fly_node2noc module
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "on_the_fly_node2noc.v"

module testbench_on_the_fly
	#(
	parameter	N_BITS_POINTER	=	clog2(`TABLE_PENDING_NODE2NOC_WIDTH)
	)
	();

	`include "NIC_utils.vh"

	reg	clk;
	reg	rst;

	//clock
	always #5 clk = ~clk;

	//to insert new transaction
	reg														new_pending_transaction_i;
	reg	[`N_BIT_SRC_HEAD_FLIT-1:0]					new_sender_i;
	reg	[`N_BIT_DEST_HEAD_FLIT-1:0]				new_recipient_i;
	reg	[`N_BIT_CMD_HEAD_FLIT-1:0]					new_transaction_type_i;

	//to query the table
	reg														query_i;
	reg	[`N_BIT_SRC_HEAD_FLIT-1:0]					query_sender_i;
	reg	[`N_BIT_DEST_HEAD_FLIT-1:0]				query_recipient_i;
	reg	[`N_BIT_CMD_HEAD_FLIT-1:0]					query_transaction_type_i;
	reg														delete_transaction_i;
	wire														is_a_pending_transaction_o;

	on_the_fly_node2noc
		#(
		.N_BITS_POINTER(N_BITS_POINTER)
		)
		table_on_the_fly
		(
		.clk(clk),
		.rst(rst),
	
		//to insert new transaction
		.new_pending_transaction_i(new_pending_transaction_i),
		.new_sender_i(new_sender_i),
		.new_recipient_i(new_recipient_i),
		.new_transaction_type_i(new_transaction_type_i),

		//to query the table
		.query_i(query_i),
		.query_sender_i(query_sender_i),
		.query_recipient_i(query_recipient_i),
		.query_transaction_type_i(query_transaction_type_i),
		.delete_transaction_i(delete_transaction_i),
		.is_a_pending_transaction_o(is_a_pending_transaction_o)
		);

	initial begin
		clk = 1;
		rst = 1;
		new_pending_transaction_i = 0;
		new_sender_i = 0;
		new_recipient_i = 0;
		new_transaction_type_i = 0;
		query_i = 0;
		query_sender_i = 0;
		query_recipient_i = 0;
		query_transaction_type_i = 0;
		delete_transaction_i = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		new_pending_transaction_i = 1;
		new_sender_i = 1;
		new_recipient_i = 2;
		new_transaction_type_i = 0;
		@(posedge clk);
		new_pending_transaction_i = 0;
		@(posedge clk);
		new_pending_transaction_i = 1;
		new_sender_i = 2;
		new_recipient_i = 2;
		new_transaction_type_i = 0;
		query_i = 1;
		query_sender_i = 1;
		query_recipient_i = 2;
		query_transaction_type_i = 0;
		delete_transaction_i = 1;
		@(posedge clk);
		new_pending_transaction_i = 1;
		new_sender_i = 3;
		new_recipient_i = 2;
		new_transaction_type_i = 0;
		query_i = 1;
		query_sender_i = 1;
		query_recipient_i = 2;
		query_transaction_type_i = 0;
		delete_transaction_i = 0;
		@(posedge clk);
		new_pending_transaction_i = 0;
		query_sender_i = 3;
		@(posedge clk);
		@(posedge clk);
		$finish;
	end//initial

endmodule//testbench_on_the_fly
