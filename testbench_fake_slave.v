`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_fake_slave 
// Project Name:	NIC_base
// Description:	Testbench fake slave
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "fake_slave_pipeline_noBurst.v"

module testbench_fake_slave();

	reg	clk;

	//clock
	always #5 clk = ~clk;

	//input of fake slave
	reg																CYC_I;
	reg																STB_I;
	reg																WE_I;
	reg			[`BUS_ADDRESS_WIDTH-1:0]					ADR_I;
	reg			[`BUS_DATA_WIDTH-1:0]						DAT_I;
	reg			[(`BUS_DATA_WIDTH/`GRANULARITY)-1:0]	SEL_I;
	reg			[2:0]												CTI_I;

	//output of fake_slave
	wire																gnt_wb_o;
	wire			[`BUS_DATA_WIDTH-1:0]						DAT_O;
	wire																ACK_O;
	wire																RTY_O;
	wire																ERR_O;
	wire																STALL_O;

	fake_slave_pipeline_noBurst fake_slave
		(
		.clk(clk),
		.gnt_wb_o(gnt_wb_o),
		.CYC_I(CYC_I),
		.STB_I(STB_I),
		.WE_I(WE_I),
		.ADR_I(ADR_I),
		.DAT_I(DAT_I),
		.SEL_I(SEL_I),
		.CTI_I(CTI_I),
		.DAT_O(DAT_O),
		.ACK_O(ACK_O),
		.RTY_O(RTY_O),
		.ERR_O(ERR_O),
		.STALL_O(STALL_O)
		);

	initial begin
		clk = 0;
		CYC_I = 0;
		STB_I = 0;
		WE_I = 0;
		ADR_I = 0;
		DAT_I = 0;
		SEL_I = 0;
		CTI_I = `CTI_CLASSIC_CYCLE;
		repeat(2) @(posedge clk);
		CYC_I = 1;
		repeat(3) @(posedge clk);
		STB_I = 1;
		repeat(6) @(posedge clk);
		STB_I = 0;
		repeat(4) @(posedge clk);
		CYC_I = 0;
		@(posedge clk);
		@(posedge clk);
		$finish;
	end//initial

endmodule//testbench_fake_slave
