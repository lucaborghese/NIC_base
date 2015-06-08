`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  
// Module Name:	testbench_fifo_out_buffer 
// Project Name:	NIC_base
// Description:	Testbench of fifo_out_buffer module
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "fifo_out_buffer.v"

module testbench_fifo_out_buffer
	#(
	parameter	N_BITS_VNET_ID			=	clog2(`N_OF_VN),
	parameter	N_BITS_VC_ID			=	`N_OF_VC*`N_OF_VN,
	parameter	N_BITS_CREDIT			=	clog2(`MAX_CREDIT),
	parameter	N_BITS_PACKET_LENGHT	=	clog2(`MAX_PACKET_LENGHT)
	)
	();

	`include "NIC_utils.vh"

	reg	clk;
	reg	rst;

	//clock
	always #5 clk=~clk;

	//input pkt
	reg	[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]	pkt_i;
	reg	[N_BITS_VNET_ID-1:0]							vnet_id_i;
	reg														is_valid_i;

	//VA side
	wire								r_va_o;
	wire	[N_BITS_VNET_ID-1:0]	vnet_id_o;
	reg								g_va_i;
	reg	[N_BITS_VC_ID-1:0]	vc_id_i;

	//LA side and flit output
	wire							r_la_o;
	wire	[`FLIT_WIDTH-1:0]	flit_o;
	wire							is_valid_o;
	reg							g_la_i;

	//fifo status pointer side
	reg	credit_in_i;
	wire	release_pointer_o;
	wire	[N_BITS_VC_ID-1:0]	vc_id_o;

	wire	free_slot_o;

	fifo_out_buffer
		#(
		.N_BITS_VNET_ID(N_BITS_VNET_ID),
		.N_BITS_VC_ID(N_BITS_VC_ID),
		.N_BITS_CREDIT(N_BITS_CREDIT),
		.N_BITS_PACKET_LENGHT(N_BITS_PACKET_LENGHT)
		)
		fifo_buffer
		(
		.clk(clk),
		.rst(rst),

		//input pkt
		.pkt_i(pkt_i),
		.vnet_id_i(vnet_id_i),
		.is_valid_i(is_valid_i),
		//VA side
		.r_va_o(r_va_o),
		.vnet_id_o(vnet_id_o),
		.g_va_i(g_va_i),
		.vc_id_i(vc_id_i),
		//LA side
		.r_la_o(r_la_o),
		.flit_o(flit_o),
		.is_valid_o(is_valid_o),
		.g_la_i(g_la_i),
		//FIFO status pointer side
		.credit_in_i(credit_in_i),
		.release_pointer_o(release_pointer_o),
		.vc_id_o(vc_id_o),
		.free_slot_o(free_slot_o)
		);

	initial begin
		clk = 0;
		rst = 1;
		pkt_i = 0;
		vnet_id_i = 0;
		is_valid_i = 0;
		g_va_i = 0;
		vc_id_i = 0;
		g_la_i = 0;
		credit_in_i = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		is_valid_i = 1;
		pkt_i = 80'hFFF2DDD1CCC1BBB10000;
		@(posedge clk);
		is_valid_i = 0;
		@(posedge clk);
		@(posedge clk);
		g_va_i = 1;
		vc_id_i = 1;
		@(posedge clk);
		g_va_i = 0;
		@(posedge clk);
		@(posedge clk);
		g_la_i = 1;
		@(posedge clk);
		g_la_i = 1;
		@(posedge clk);
		g_la_i = 0;
		@(posedge clk);
		g_la_i = 0;
		@(posedge clk);
		g_la_i = 1;
		@(posedge clk);
		g_la_i = 0;
		@(posedge clk);
		@(posedge clk);
		credit_in_i = 1;
		@(posedge clk);
		@(posedge clk);
		g_la_i = 1;
		@(posedge clk);
		credit_in_i = 0;
		g_la_i = 1;
		@(posedge clk);
		g_la_i = 0;
		@(posedge clk);
		@(posedge clk);
		$finish;
	end//initial

endmodule//testbench_fifo_out_buffer
