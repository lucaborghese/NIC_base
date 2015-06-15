`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Module Name:	testbench_fake_master 
// Project Name:	NIC_base
// Description:	Testbench for fa_master 
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "fake_master.v"

module testbench_fake_master
	#(
	parameter MORE_READ						=	0,//0 more write, 1 more read(see also HOW_MANY_MORE_READ/WRITE)
	parameter MORE_SMALL_WRITE				=	0,//0 more big write, 1 more small write(see also HOW_MANY_MORE_SMALL)
	parameter HOW_MANY_MORE_READ			=	0,//greater this number greater the probability to have more read/write than write/read
	parameter HOW_MANY_MORE_SMALL			=	10,//greater this number greater the probability to have more small/big write than big/small
	parameter N_BODY_FLIT					=	`MAX_PACKET_LENGHT-2
	)
	();

	reg clk;
	reg rst;

	//clock
	always #5 clk=~clk;

	//WISHBONE interface
	wire										CYC_O;
	wire										STB_O;
	wire										WE_O;
	wire	[`BUS_DATA_WIDTH-1:0]		DAT_O;
	wire	[`BUS_SEL_WIDTH-1:0]			SEL_O;
	wire	[`BUS_ADDRESS_WIDTH-1:0]	ADR_O;
	wire	[2:0]								CTI_O;
	reg	[`BUS_DATA_WIDTH-1:0]		DAT_I;
	reg										ACK_I;
	reg										RTY_I;
	reg										ERR_I;
	reg										STALL_I;
	//arbiter interface
	reg gnt_wb_i;

	fake_master
		#(
		.MORE_READ(MORE_READ),
		.MORE_SMALL_WRITE(MORE_SMALL_WRITE),
		.HOW_MANY_MORE_READ(HOW_MANY_MORE_READ),
		.HOW_MANY_MORE_SMALL(HOW_MANY_MORE_SMALL),
		.N_BODY_FLIT(N_BODY_FLIT)
		)
		fake_master
		(
		.clk(clk),
		.rst(rst),

		//WISHBONE interface
		.CYC_O(CYC_O),
		.STB_O(STB_O),
		.WE_O(WE_O),
		.DAT_O(DAT_O),
		.SEL_O(SEL_O),
		.ADR_O(ADR_O),
		.CTI_O(CTI_O),
		.DAT_I(DAT_I),
		.ACK_I(ACK_I),
		.RTY_I(RTY_I),
		.ERR_I(ERR_I),
		.STALL_I(STALL_I),
		//arbiter interface
		.gnt_wb_i(gnt_wb_i)
		);

	initial begin
		clk = 0;
		rst = 1;
		gnt_wb_i = 0;
		ACK_I = 0;
		RTY_I = 0;
		ERR_I = 0;
		STALL_I = 0;
		DAT_I = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		@(posedge clk);
		gnt_wb_i = 1;
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		ACK_I = 1;
		@(posedge clk);
		ACK_I = 0;
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		ACK_I = 1;
		@(posedge clk);
		ACK_I = 0;
		@(posedge clk);
		@(posedge clk);
		ACK_I = 1;
		@(posedge clk);
		ACK_I = 0;
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		$finish;
	end//initial

endmodule//testbench_fake_master
