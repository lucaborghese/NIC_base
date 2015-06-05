`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_wb_slave_interface 
// Project Name:	NIC_base
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "wb_slave_interface.v"

module testbench_wb_slave_interface
	#(
	parameter	N_BITS_BURST_LENGHT		=	clog2(`MAX_BURST_LENGHT),
	parameter	N_BITS_PACKET_LENGHT		=	clog2(`MAX_PACKET_LENGHT),
	parameter	N_FIFO_OUT_BUFFER			=	`N_FIFO_OUT_BUFFER,
	parameter	N_BITS_FIFO_OUT_BUFFER	=	clog2(N_FIFO_OUT_BUFFER),
	parameter	N_BITS_VNET_ID				=	clog2(`N_OF_VN),
	parameter	N_TOT_OF_VC					=	`N_OF_VN*`N_OF_VC,
	parameter	N_BITS_CREDIT				=	4
	)
	();

	`include "NIC_utils.vh"

	reg clk;
	reg rst;

	//clock
	always #5 clk=~clk;

	//on_the_fly_node2noc table side
	wire														new_pending_transaction_o;
	wire	[`N_BIT_SRC_HEAD_FLIT-1:0]					new_sender_o;
	wire	[`N_BIT_DEST_HEAD_FLIT-1:0]				new_recipient_o;
	wire	[`N_BIT_CMD_HEAD_FLIT-1:0]					new_transaction_type_o;

	//link_allocator side
	wire	[N_FIFO_OUT_BUFFER-1:0]			r_la_o;
	reg											g_la_i;
	reg	[N_BITS_FIFO_OUT_BUFFER-1:0]	g_la_fifo_out_buffer_id_i;

	//vc_allocator side
	wire	[N_FIFO_OUT_BUFFER-1:0]					r_va_o;
	wire	[N_FIFO_OUT_BUFFER*N_TOT_OF_VC-1:0]	r_vc_requested_o;
	reg	[N_FIFO_OUT_BUFFER-1:0]					g_va_i;
	reg	[N_FIFO_OUT_BUFFER*N_TOT_OF_VC-1:0]	g_va_vc_id_i;

	//WISHBONE bus side
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

	//fifo side
	wire	[N_TOT_OF_VC-1:0]									g_fifo_pointer_o;
	wire	[N_TOT_OF_VC*N_BITS_FIFO_OUT_BUFFER-1:0]	g_fifo_out_buffer_id_o;
	wire	[N_TOT_OF_VC-1:0]									release_pointer_o;
	reg	[N_TOT_OF_VC-1:0]									credit_signal_i;
	reg	[N_TOT_OF_VC*N_BITS_FIFO_OUT_BUFFER-1:0]	fifo_pointed_i;
	wire	[`FLIT_WIDTH-1:0]									out_link_o;
	wire															is_valid_o;

	wb_slave_interface
		#(
		.N_BITS_BURST_LENGHT(N_BITS_BURST_LENGHT),
		.N_BITS_PACKET_LENGHT(N_BITS_PACKET_LENGHT),
		.N_FIFO_OUT_BUFFER(N_FIFO_OUT_BUFFER),
		.N_BITS_FIFO_OUT_BUFFER(N_BITS_FIFO_OUT_BUFFER),
		.N_BITS_VNET_ID(N_BITS_VNET_ID),
		.N_TOT_OF_VC(N_TOT_OF_VC),
		.N_BITS_CREDIT(N_BITS_CREDIT)
		)
		slave_interface
		(
		.clk(clk),
		.rst(rst),

		//on_the_fly_node2noc table side
		.new_pending_transaction_o(new_pending_transaction_o),
		.new_sender_o(new_sender_o),
		.new_recipient_o(new_recipient_o),
		.new_transaction_type_o(new_transaction_type_o),

		//link_allocator side
		.r_la_o(r_la_o),
		.g_la_i(g_la_i),
		.g_la_fifo_out_buffer_id_i(g_la_fifo_out_buffer_id_i),

		//vc_allocator side
		.r_va_o(r_va_o),
		.r_vc_requested_o(r_vc_requested_o),
		.g_va_i(g_va_i),
		.g_va_vc_id_i(g_va_vc_id_i),

		//WISHBONE bus side
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

		//fifo side
		.g_fifo_pointer_o(g_fifo_pointer_o),
		.g_fifo_out_buffer_id_o(g_fifo_out_buffer_id_o),
		.release_pointer_o(release_pointer_o),
		.credit_signal_i(credit_signal_i),
		.fifo_pointed_i(fifo_pointed_i),
		.out_link_o(out_link_o),
		.is_valid_o(is_valid_o)
		);

		initial begin
		clk = 0;
		rst = 1;
		g_la_i = 0;//grant del stadio di LA(1 bit)
		g_la_fifo_out_buffer_id_i = 0;//chi ha vinto lo stage di LA, unsigned decimal(N_BITS_FIFO_OUT_BUFFER bits)
		g_va_i = 0;//chi ha vinto lo stage di VA(N_FIFO_OUT_BUFFER bits, un bit per richiesta)
		g_va_vc_id_i = 0;//quale vc è stato assegnato a chi ha vinto(N_FIFO_OUT_BUFFER*N_TOT_OF_VC bits)
		credit_signal_i = 0;//N_TOT_OF_VC signals
		fifo_pointed_i = 0;//N_TOT_OF_VC*N_BITS_FIFO_OUT_BUFFER bits
		//WISHBONE
		CYC_I = 0;
		STB_I = 0;
		CTI_I = 0;
		WE_I = 0;
		DAT_I = 0;
		ADR_I = 0;
		SEL_I = 0;
		ACK_I = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		ACK_I = 1;
		repeat(5) @(posedge clk);
		ACK_I = 0;
		@(posedge clk);
		ACK_I = 1;
		repeat(5) @(posedge clk);
		ACK_I = 0;
		@(posedge clk);
		ACK_I = 1;
		repeat(5) @(posedge clk);
		ACK_I = 0;

/*		CYC_I = 1;
		@(posedge clk)
		STB_I = 1;
		repeat(4) @(posedge clk);
		STB_I = 0;
*/		@(posedge clk);
		@(posedge clk);
		g_va_i = 6'b000001;
		g_va_vc_id_i = 36'b000000000001;
		@(posedge clk);
		g_va_i = 0;
		g_la_i = 1;
		g_la_fifo_out_buffer_id_i = 0;
		repeat(5) @(posedge clk);
		g_la_i = 0;
		@(posedge clk);
		$finish;
	end//initial

endmodule//testbench_wb_slave_interface
