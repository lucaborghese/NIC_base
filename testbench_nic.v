`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_nic 
// Project Name:	NIC_base
// Description: 
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC.v"
`include "NIC-defines.v"

module testbench_nic
	#(
	parameter N_TOT_OF_VC						=	`N_OF_VC*`N_OF_VN
	)
	();

	reg clk;
	reg rst;

	always #5 clk=~clk;

	//router => NIC
	reg	[`FLIT_WIDTH-1:0]	in_link_i;
	reg 							is_valid_i;
	reg	[N_TOT_OF_VC-1:0]	credit_signal_i;
	reg	[N_TOT_OF_VC-1:0]	free_signal_i;

	//NIC => router
	wire	[`FLIT_WIDTH-1:0]	out_link_o;
	wire							is_valid_o;
	wire							credit_signal_o;
	wire							free_signal_o;

	//NIC(MASTER) => NODE(SLAVE)
	reg	[`BUS_DATA_WIDTH-1:0]		DAT_NIC_NODE_I;
	reg										ACK_NIC_NODE_I;
	reg										RTY_NIC_NODE_I;
	reg										ERR_NIC_NODE_I;
	reg										STALL_NIC_NODE_I;
	wire										CYC_NIC_NODE_O;
	wire										STB_NIC_NODE_O;
	wire										WE_NIC_NODE_O;
	wire	[`BUS_ADDRESS_WIDTH-1:0]	ADR_NIC_NODE_O;
	wire	[`BUS_DATA_WIDTH-1:0]		DAT_NIC_NODE_O;
	wire	[`BUS_SEL_WIDTH-1:0]			SEL_NIC_NODE_O;
	wire	[2:0]								CTI_NIC_NODE_O;

	//NODE(MASTER) => NIC(SLAVE)
	reg										CYC_NODE_NIC_I;
	reg										STB_NODE_NIC_I;
	reg	[2:0]								CTI_NODE_NIC_I;
	reg										WE_NODE_NIC_I;
	reg	[`BUS_DATA_WIDTH-1:0]		DAT_NODE_NIC_I;
	reg	[`BUS_ADDRESS_WIDTH-1:0]	ADR_NODE_NIC_I;
	reg	[`BUS_SEL_WIDTH-1:0]			SEL_NODE_NIC_I;
	wire	[`BUS_DATA_WIDTH-1:0]		DAT_NODE_NIC_O;
	wire										RTY_NODE_NIC_O;
	wire										ERR_NODE_NIC_O;
	wire										STALL_NODE_NIC_O;
	wire										ACK_NODE_NIC_O;

	//WB arbiter
	reg										gnt_wb_i;

	NIC nic
		(
		.clk(clk),
		.rst(rst),

		//router => NIC
		.in_link_i(in_link_i),
		.is_valid_i(is_valid_i),
		.credit_signal_i(credit_signal_i),
		.free_signal_i(free_signal_i),
		//NIC => router
		.out_link_o(out_link_o),
		.is_valid_o(is_valid_o),
		.credit_signal_o(credit_signal_o),
		.free_signal_o(free_signal_o),
		//NIC(MASTER) => NODE(SLAVE)
		.DAT_NIC_NODE_I(DAT_NIC_NODE_I),
		.ACK_NIC_NODE_I(ACK_NIC_NODE_I),
		.RTY_NIC_NODE_I(RTY_NIC_NODE_I),
		.ERR_NIC_NODE_I(ERR_NIC_NODE_I),
		.STALL_NIC_NODE_I(STALL_NIC_NODE_I),
		.CYC_NIC_NODE_O(CYC_NIC_NODE_O),
		.STB_NIC_NODE_O(STB_NIC_NODE_O),
		.WE_NIC_NODE_O(WE_NIC_NODE_O),
		.ADR_NIC_NODE_O(ADR_NIC_NODE_O),
		.DAT_NIC_NODE_O(DAT_NIC_NODE_O),
		.SEL_NIC_NODE_O(SEL_NIC_NODE_O),
		.CTI_NIC_NODE_O(CTI_NIC_NODE_O),
		//NODE(MASTER) => NIC(SLAVE)
		.CYC_NODE_NIC_I(CYC_NODE_NIC_I),
		.STB_NODE_NIC_I(STB_NODE_NIC_I),
		.CTI_NODE_NIC_I(CTI_NODE_NIC_I),
		.WE_NODE_NIC_I(WE_NODE_NIC_I),
		.DAT_NODE_NIC_I(DAT_NODE_NIC_I),
		.ADR_NODE_NIC_I(ADR_NODE_NIC_I),
		.SEL_NODE_NIC_I(SEL_NODE_NIC_I),
		.DAT_NODE_NIC_O(DAT_NODE_NIC_O),
		.RTY_NODE_NIC_O(RTY_NODE_NIC_O),
		.ERR_NODE_NIC_O(ERR_NODE_NIC_O),
		.STALL_NODE_NIC_O(STALL_NODE_NIC_O),
		.ACK_NODE_NIC_O(ACK_NODE_NIC_O),
		//WB arbiter
		.gnt_wb_i(gnt_wb_i)
		);

/*	initial begin//noc2wb
		fork
			//write long packet from NoC to wb
			repeat(6) begin
				repeat(2) @(posedge clk);
				in_link_i = ( $random & 16'hFFF0 | 16'h0000 );//head
				is_valid_i = 1;
				@(posedge clk);
				in_link_i = ( $random & 16'hFFF0 | 16'h0001 );
				@(posedge clk);
				in_link_i = ( $random & 16'hFFF0 | 16'h0001 );
				@(posedge clk);
				is_valid_i = 0;//pause
				@(posedge clk);
				in_link_i = ( $random & 16'hFFF0 | 16'h0001 );
				is_valid_i = 1;
				@(posedge clk);
				in_link_i = ( $random & 16'hFFF0 | 16'h0002 );
				@(posedge clk);
				is_valid_i = 0;//all the packet arrives
				@(posedge clk);
				@(posedge clk);
			end
			repeat(6) begin
				repeat(10) @(posedge clk);
				gnt_wb_i = 1;
				@(posedge clk);
				@(posedge clk);
				ACK_NIC_NODE_I = 1;
				@(posedge clk);
				@(posedge clk);
				@(posedge clk);
				ACK_NIC_NODE_I = 0;
				gnt_wb_i = 0;
				repeat(4) @(posedge clk);
			end
		join
		$finish;
	end
*/
	initial begin
		clk = 0;
		rst = 1;

		in_link_i = 0;
		is_valid_i = 0;
		credit_signal_i = 0;
		free_signal_i = 0;

		DAT_NIC_NODE_I = 0;
		ACK_NIC_NODE_I = 0;
		RTY_NIC_NODE_I = 0;
		ERR_NIC_NODE_I = 0;
		STALL_NIC_NODE_I = 0;

		CYC_NODE_NIC_I = 0;
		STB_NODE_NIC_I = 0;
		CTI_NODE_NIC_I = 0;
		WE_NODE_NIC_I = 0;
		DAT_NODE_NIC_I = 0;
		ADR_NODE_NIC_I = 0;
		SEL_NODE_NIC_I = ~0;

		gnt_wb_i = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		
/*		//big write from the bus
		repeat(3) begin
		CYC_NODE_NIC_I = 1;
		STB_NODE_NIC_I = 1;
		WE_NODE_NIC_I = 1;
		ADR_NODE_NIC_I = 16'h0004;//head
		DAT_NODE_NIC_I = 32'hbbb10004;//first chunk
		@(posedge clk);
		DAT_NODE_NIC_I = 32'hddd1ccc1;//second chunk
		@(posedge clk);
		DAT_NODE_NIC_I = 32'h0000fff2;//last chunk
		@(posedge clk);
		STB_NODE_NIC_I = 0;
		@(posedge clk);
		CYC_NODE_NIC_I = 0;
		@(posedge clk);
		end
*/
/*		//several small write and a big write
		CYC_NODE_NIC_I = 1;
		STB_NODE_NIC_I = 1;
		WE_NODE_NIC_I = 1;
		ADR_NODE_NIC_I = 16'h9003;//head
		DAT_NODE_NIC_I = 32'h00009003;//first chunk
		@(posedge clk);
		STB_NODE_NIC_I = 0;
		@(posedge clk);
		CYC_NODE_NIC_I = 0;
		@(posedge clk);

		CYC_NODE_NIC_I = 1;
		STB_NODE_NIC_I = 1;
		WE_NODE_NIC_I = 1;
		ADR_NODE_NIC_I = 16'h9013;//head
		DAT_NODE_NIC_I = 32'h00009013;//first chunk
		@(posedge clk);
		STB_NODE_NIC_I = 0;
		@(posedge clk);
		CYC_NODE_NIC_I = 0;
		@(posedge clk);

		CYC_NODE_NIC_I = 1;
		STB_NODE_NIC_I = 1;
		WE_NODE_NIC_I = 1;
		ADR_NODE_NIC_I = 16'h4003;//head
		DAT_NODE_NIC_I = 32'h00004003;//first chunk
		@(posedge clk);
		STB_NODE_NIC_I = 0;
		@(posedge clk);
		CYC_NODE_NIC_I = 0;
		@(posedge clk);

		free_signal_i = 4'b0001;

		CYC_NODE_NIC_I = 1;
		STB_NODE_NIC_I = 1;
		WE_NODE_NIC_I = 1;
		ADR_NODE_NIC_I = 16'h0004;//head
		DAT_NODE_NIC_I = 32'hbbb10004;//first chunk
		@(posedge clk);
		free_signal_i = 0;
		DAT_NODE_NIC_I = 32'hddd1ccc1;//second chunk
		@(posedge clk);
		DAT_NODE_NIC_I = 32'h0000fff2;//last chunk
		@(posedge clk);
		STB_NODE_NIC_I = 0;
		@(posedge clk);
		CYC_NODE_NIC_I = 0;
		@(posedge clk);

		CYC_NODE_NIC_I = 1;
		STB_NODE_NIC_I = 1;
		WE_NODE_NIC_I = 1;
		ADR_NODE_NIC_I = 16'h5013;//head
		DAT_NODE_NIC_I = 32'h00005013;//first chunk
		@(posedge clk);
		STB_NODE_NIC_I = 0;
		@(posedge clk);
		CYC_NODE_NIC_I = 0;
		repeat(5) @(posedge clk);
*/
/*
		//read from the wb
		CYC_NODE_NIC_I = 1;//read command
		STB_NODE_NIC_I = 1;
		WE_NODE_NIC_I = 0;
		ADR_NODE_NIC_I = 16'h9F03;//head
		DAT_NODE_NIC_I = 32'h00000000;//first chunk
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		STB_NODE_NIC_I = 0;
		repeat(5) @(posedge clk);

		//reply
		in_link_i = 16'h6F00;//head
		is_valid_i = 1;
		@(posedge clk);
		in_link_i = 16'hBBB1;
		@(posedge clk);
		in_link_i = 16'hCCC1;
		@(posedge clk);
		is_valid_i = 0;//pause
		@(posedge clk);
		in_link_i = 16'hDDD1;
		is_valid_i = 1;
		@(posedge clk);
		in_link_i = 16'hFFF2;
		@(posedge clk);
		is_valid_i = 0;//all the packet arrives
		repeat(6) @(posedge clk);
		CYC_NODE_NIC_I = 0;
		@(posedge clk);
		@(posedge clk);
*/

		//read from the noc and reply of wishbone bus
		in_link_i = 16'h6F03;//head
		is_valid_i = 1;
		@(posedge clk);
		is_valid_i = 0;
		repeat(3) @(posedge clk);
		gnt_wb_i = 1;
		repeat(3) @(posedge clk);
		ACK_NIC_NODE_I = 1;
		DAT_NIC_NODE_I = 32'hbbb10000;
		@(posedge clk);
		DAT_NIC_NODE_I = 32'hddd1ccc1;
		@(posedge clk);
		DAT_NIC_NODE_I = 32'h0000fff2;
		@(posedge clk);
		ACK_NIC_NODE_I = 0;
		repeat(9) @(posedge clk);
		$finish;
	end//initial

endmodule//testbench_nic
