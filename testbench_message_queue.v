`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_message_queue 
// Project Name:	NIC_base 
// Description:	Testbench for message_queue module
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "message_queue.v"

module testbench_message_queue
	#(
	parameter	N_BITS_POINTER				=	clog2(`QUEUE_WIDTH),
	parameter	N_BITS_BURST_LENGHT		=	clog2(`MAX_BURST_LENGHT)
	)
	();

	`include "NIC_utils.vh"

	reg	clk;
	reg	rst;

	//input message queue NoC side
	reg	[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	in_link;
	reg	[`MAX_PACKET_LENGHT-1:0]					in_sel;
	reg														r_pkt_to_msg_i;

	//output message queue NoC side
	wire														g_pkt_to_msg_o;

	//input message queue WB interface side
	reg														message_transmitted_i;
	reg														next_data_i;
	reg														retry_i;

	//output message queue WB interface side
	wire														r_bus_arbitration_o;
	wire	[`BUS_ADDRESS_WIDTH-1:0]					address_o;//if r_bus_arbitration_o is high this signal contains the address that must be trasmitted on the WISHBONE
	wire	[`BUS_DATA_WIDTH-1:0]						data_o;//like above, but the signal contains the data
	wire	[(`BUS_DATA_WIDTH/`GRANULARITY)-1:0]	sel_o;//like above, but contains the SEL_O signal
	wire														transaction_type_o;//like above, but this signal contains the WE_O signal of WISHBONE
	wire	[N_BITS_BURST_LENGHT-1:0]					burst_lenght_o;

	always #5 clk = ~clk;

	message_queue
		#(
		.N_BITS_POINTER(N_BITS_POINTER),
		.N_BITS_BURST_LENGHT(N_BITS_BURST_LENGHT)
		)
		queue
		(
		.clk(clk),
		.rst(rst),
		.in_link_i(in_link),
		.in_sel_i(in_sel),
		.r_pkt_to_msg_i(r_pkt_to_msg_i),
		.g_pkt_to_msg_o(g_pkt_to_msg_o),
		.message_transmitted_i(message_transmitted_i),
		.next_data_i(next_data_i),
		.retry_i(retry_i),
		.r_bus_arbitration_o(r_bus_arbitration_o),
		.address_o(address_o),
		.data_o(data_o),
		.sel_o(sel_o),
		.transaction_type_o(transaction_type_o),
		.burst_lenght_o(burst_lenght_o)
		);

/*
	//big write
	initial begin
		clk = 0;
		rst = 1;
		r_pkt_to_msg_i = 0;
		in_link = 0;
		in_sel = 0;
		message_transmitted_i = 0;
		next_data_i = 0;
		retry_i = 0;
		repeat (2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		r_pkt_to_msg_i = 1;
		in_link = 80'hFFF2BBB1BBB1BBB10000;
		in_sel = 5'b11111;
		@(posedge clk);
		@(posedge clk);
		r_pkt_to_msg_i = 0;
		next_data_i = 1;
		@(posedge clk);
		@(posedge clk);
		next_data_i = 0;
		@(posedge clk);
		retry_i = 1;
		@(posedge clk);
		retry_i = 0;
		next_data_i = 1;
		repeat(4) @(posedge clk);
		next_data_i = 0;
		message_transmitted_i = 1;
		@(posedge clk);
		message_transmitted_i = 0;
		@(posedge clk);
		$finish;
	end//initial
*/
/*
	//saturate memory
	initial begin
		clk = 0;
		rst = 1;
		r_pkt_to_msg_i = 0;
		in_link = 0;
		in_sel = 0;
		message_transmitted_i = 0;
		next_data_i = 0;
		retry_i = 0;
		repeat (2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		r_pkt_to_msg_i = 1;
		in_link = 80'hFFF2BBB1BBB1BBB10000;
		in_sel = 5'b11111;
		fork
			repeat(30) @(posedge clk);
			repeat(15) begin
				@(posedge clk);
				@(posedge clk);
				message_transmitted_i = 1;
				@(posedge clk);
				message_transmitted_i = 0;
			end
		join
		$finish;
	end//initial
*/
	//small message
	initial begin
		clk = 0;
		rst = 1;
		r_pkt_to_msg_i = 0;
		in_link = 0;
		in_sel = 0;
		message_transmitted_i = 0;
		next_data_i = 0;
		retry_i = 0;
		repeat (2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		r_pkt_to_msg_i = 1;
		in_link = 80'h00000000000000000003;
		in_sel = 5'b00001;
		@(posedge clk);
		@(posedge clk);
		r_pkt_to_msg_i = 0;
		@(posedge clk);
		@(posedge clk);
		$finish;
	end//initial

endmodule
