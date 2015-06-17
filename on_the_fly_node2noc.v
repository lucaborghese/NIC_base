//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	on_the_fly_node2noc 
// Project Name:	NIC_base
// Description:	table containing the pending transaction of the masters attached on the local WISHBONE bus 
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"

module on_the_fly_node2noc
	#(
	parameter	N_BITS_POINTER	=	3
	)
	(
	input						clk,
	input						rst,

	//to insert new transactions
	input																	new_pending_transaction_i,//high if the new_* signals are valid
	input				[`N_BIT_SRC_HEAD_FLIT-1:0]					new_sender_i,//sender of the new pending transaction
	input				[`N_BIT_DEST_HEAD_FLIT-1:0]				new_recipient_i,//recipient of the new pending transaction
	input				[`N_BIT_CMD_HEAD_FLIT-1:0]					new_transaction_type_i,//type of the new pending transaction

	//query the table
	input																	query_i,//high if query_* are valid, and at soon as possible is_a_pending_query will be valid
	input				[`N_BIT_SRC_HEAD_FLIT-1:0]					query_sender_i,
	input				[`N_BIT_DEST_HEAD_FLIT-1:0]				query_recipient_i,
	input				[`N_BIT_CMD_HEAD_FLIT-1:0]					query_transaction_type_i,
	input																	delete_transaction_i,//if high with query_i, it deletes the queried transaction if exist at the end of the cycle
	output	reg														is_a_pending_transaction_o//query reply, combinatorial
	);

	`include "NIC_utils.vh"

	//table
	reg	[`TABLE_PENDING_NODE2NOC_WIDTH-1:0]		valid_bit_r;
	reg	[`N_BIT_SRC_HEAD_FLIT-1:0]					sender_r[`TABLE_PENDING_NODE2NOC_WIDTH-1:0];
	reg	[`N_BIT_DEST_HEAD_FLIT-1:0]				recipient_r[`TABLE_PENDING_NODE2NOC_WIDTH-1:0];
	reg	[`N_BIT_CMD_HEAD_FLIT-1:0]					transaction_type_r[`TABLE_PENDING_NODE2NOC_WIDTH-1:0];
	reg	[N_BITS_POINTER-1:0]							next_free_slot_pointer;
	reg	[N_BITS_POINTER-1:0]							query_result_pointer;
	reg	[`TABLE_PENDING_NODE2NOC_WIDTH-1:0]		next_valid_bit;

	//computation of next_free_slot_pointer
	always @(*) begin
		next_free_slot_pointer = ff1(~valid_bit_r,`TABLE_PENDING_NODE2NOC_WIDTH);
	end//always

	//computation of a query
	integer k0;
	always @(*) begin
		query_result_pointer = 0;
		is_a_pending_transaction_o = 0;
		if(query_i) begin
			for( k0=0 ; k0<`TABLE_PENDING_NODE2NOC_WIDTH ; k0=k0+1 ) begin
				if(valid_bit_r[k0] && !is_a_pending_transaction_o) begin
					if(query_sender_i==sender_r[k0] && query_recipient_i==recipient_r[k0] /*&& query_transaction_type_i==transaction_type_r[k0]*/) begin
						query_result_pointer = k0;
						is_a_pending_transaction_o = 1;
					end
				end//if(valid_bit_r[k0])
			end//for
		end//else if(query_i || delete_transaction_i)
	end//always

	//storing a new entry
	always @(posedge clk) begin
		if(new_pending_transaction_i) begin
			sender_r[next_free_slot_pointer] <= new_sender_i;
			recipient_r[next_free_slot_pointer] <= new_recipient_i;
			transaction_type_r[next_free_slot_pointer] <= new_transaction_type_i;
		end//if(new_pending_transaction_i)
	end//always

	//computation of next_valid_bit
	always @(*) begin
		next_valid_bit = valid_bit_r;
		if(new_pending_transaction_i) begin
			next_valid_bit[next_free_slot_pointer] = 1;
		end
		if(delete_transaction_i && is_a_pending_transaction_o) begin
			next_valid_bit[query_result_pointer] = 0;
		end
	end//always

	//update of valid_bit_r
	always @(posedge clk) begin
		if(rst) begin
			valid_bit_r <= 0;
		end else begin
			valid_bit_r <= next_valid_bit;
		end//else if(rst)
	end//always

endmodule//on_the_fly_node2noc
