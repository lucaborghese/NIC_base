`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_flits_buffer 
// Project Name:	NIC_base 
// Description:	Testbench per il modulo flits_buffer
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "flits_buffer.v"

module testbench_flits_buffer
	#(
	parameter N_BITS_POINTER = clog2(`MAX_PACKET_LENGHT)
	)
	();

	`include "NIC_utils.vh"

	reg	clk;
	reg	rst;
	
	//input for flits_buffer
	reg	[`FLIT_WIDTH-1:0]	in_link;
	reg							is_valid;
	reg							stall_packet_to_message;
	
	//output from flits_buffer
	wire														credit_signal;
	wire														free_signal;
	wire														r_packet_to_message;
	wire	[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	out_link;
//	wire	[N_BITS_POINTER-1:0]							head_pointer;
//	wire	[`MAX_PACKET_LENGHT-1:0]					out_sel;
	
	//clock
	always #5 clk = ~clk;

	//flits_buffer instance
	flits_buffer
		#(
		.N_BITS_POINTER(N_BITS_POINTER)
		)
		buffer
		(
		.clk(clk),
		.rst(rst),
		.in_link_i(in_link),
		.is_valid_i(is_valid),
		.credit_signal_o(credit_signal),
		.free_signal_o(free_signal),
		.stall_pkt_to_msg_i(stall_packet_to_message),
		.r_pkt_to_msg_o(r_packet_to_message),
		.out_link_o(out_link)
//		.head_pointer_o(head_pointer),
//		.out_sel_o(out_sel)
		);

	initial begin
		clk = 0;
		rst = 1;
		in_link = 0;
		is_valid = 0;
		stall_packet_to_message = 0;
		repeat (2) @ (posedge clk);
		rst = 0;
		is_valid = 1;
		in_link = 64'hFF3;
		@ (posedge clk);
		is_valid = 0;
		@ (posedge clk);
/*		@ (posedge clk);
		@ (posedge clk);
		is_valid = 1;
		in_link = 64'h00;//head flit
		@ (posedge clk);
		in_link = 64'h11;//first body flit
		@ (posedge clk);
		in_link = 64'h21;//second body flit
		@ (posedge clk);
		is_valid = 0;//stop di un ciclo
*/		@ (posedge clk);
		is_valid = 1;
		in_link = 64'h30;//third body flit
		@ (posedge clk);
		in_link = 64'h41;//forth body flit
		@ (posedge clk);
		in_link = 64'h51;//fifth body flit
		@ (posedge clk);
		in_link = 64'h61;//sixth body flit
		@ (posedge clk);
		in_link = 64'h72;//tail flit
		@ (posedge clk);
		is_valid = 0;
		@ (posedge clk);
		$finish;
	end//

endmodule//testbench_flits_buffer
