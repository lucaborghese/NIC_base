`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	testbench_master_nic_nic_slave 
// Project Name:	NIC_base
// Description:	Testbench with schema MASTER_WB <=> NIC <=> NIC <=> SLAVE_WB 
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"
`include "NIC.v"
`include "fake_master.v"
`include "fake_slave_pipeline_noBurst.v"

module testbench_master_nic_nic_slave
	#(
	parameter N_TOT_OF_VC							=	`N_OF_VN*`N_OF_VC,
	//parameter for fake_master
	parameter MORE_READ								=	0,//0 more write, 1 more read(see also HOW_MANY_MORE_READ/WRITE)
	parameter MORE_SMALL_WRITE						=	0,//0 more big write, 1 more small write(see also HOW_MANY_MORE_SMALL)
	parameter HOW_MANY_MORE_READ					=	10,//greater this number greater the probability to have more read/write than write/read
	parameter HOW_MANY_MORE_SMALL					=	10,//greater this number greater the probability to have more small/big write than big/small
	parameter N_BODY_FLIT							=	`MAX_PACKET_LENGHT-2,
	//parameter for fake_slave
	parameter n_wait_cycle_grant					=	100,
	parameter n_wait_cycle_for_read_pipeline	=	2,
	parameter n_wait_cycle_for_write_pipeline	=	2,
	parameter insert_stall							=	0,//1: insert random stall, 0: no stall
	parameter n_wait_cycle_between_read_ack	=	0,
	parameter n_wait_cycle_between_write_ack	=	0
	)
	();

	reg clk;
	reg rst;

	//clock
	always #5 clk=~clk;

	//signals from fake_master to nic_for_master
	wire										CYC_O_MASTER_NIC;
	wire										STB_O_MASTER_NIC;
	wire										WE_O_MASTER_NIC;
	wire	[`BUS_DATA_WIDTH-1:0]		DAT_O_MASTER_NIC;
	wire	[`BUS_SEL_WIDTH-1:0]			SEL_O_MASTER_NIC;
	wire	[`BUS_TGA_WIDTH-1:0]			TGA_O_MASTER_NIC;
	wire	[`BUS_TGC_WIDTH-1:0]			TGC_O_MASTER_NIC;
	wire	[`BUS_ADDRESS_WIDTH-1:0]	ADR_O_MASTER_NIC;
	wire	[2:0]								CTI_O_MASTER_NIC;
	wire	[`BUS_DATA_WIDTH-1:0]		DAT_I_MASTER_NIC;
	wire										ACK_I_MASTER_NIC;
	wire										RTY_I_MASTER_NIC;
	wire										ERR_I_MASTER_NIC;
	wire										STALL_I_MASTER_NIC;

	reg gnt_wb_i_for_master;

	//signals for nic_for_master(there isn't a slave so fixed signals)
	reg	[`BUS_DATA_WIDTH-1:0]		DAT_NIC_MASTER_NODE_I;
	reg										ACK_NIC_MASTER_NODE_I;
	reg										RTY_NIC_MASTER_NODE_I;
	reg										ERR_NIC_MASTER_NODE_I;
	reg										STALL_NIC_MASTER_NODE_I;
	wire										CYC_NIC_MASTER_NODE_O;
	wire										STB_NIC_MASTER_NODE_O;
	wire										WE_NIC_MASTER_NODE_O;
	wire	[`BUS_ADDRESS_WIDTH-1:0]	ADR_NIC_MASTER_NODE_O;
	wire	[`BUS_DATA_WIDTH-1:0]		DAT_NIC_MASTER_NODE_O;
	wire	[`BUS_SEL_WIDTH-1:0]			SEL_NIC_MASTER_NODE_O;
	wire	[`BUS_TGA_WIDTH-1:0]			TGA_NIC_MASTER_NODE_O;
	wire	[`BUS_TGC_WIDTH-1:0]			TGC_NIC_MASTER_NODE_O;
	wire	[2:0]								CTI_NIC_MASTER_NODE_O;
	reg										gnt_wb_i_for_nic_master;

	//signals link nic_master => nic_slave
	wire	[`FLIT_WIDTH-1:0]				out_link_o_nm_ns;
	wire										is_valid_o_nm_ns;
	wire	[N_TOT_OF_VC-1:0]				credit_signal_i_nm_ns;
	wire	[N_TOT_OF_VC-1:0]				free_signal_i_nm_ns;

	//signals link nic_slave => nic_master
	wire	[`FLIT_WIDTH-1:0]				out_link_o_ns_nm;
	wire										is_valid_o_ns_nm;
	wire	[N_TOT_OF_VC-1:0]				credit_signal_i_ns_nm;
	wire	[N_TOT_OF_VC-1:0]				free_signal_i_ns_nm;

	//signals from fake_slave to nic_slave
	//arbiter
	wire										gnt_wb_o_slave_nic;
	//WISHBONE
	wire										CYC_I_SLAVE_NIC;
	wire										STB_I_SLAVE_NIC;
	wire										WE_I_SLAVE_NIC;
	wire	[`BUS_ADDRESS_WIDTH-1:0]	ADR_I_SLAVE_NIC;
	wire	[`BUS_DATA_WIDTH-1:0]		DAT_I_SLAVE_NIC;
	wire	[`BUS_SEL_WIDTH-1:0]			SEL_I_SLAVE_NIC;
	wire	[`BUS_TGA_WIDTH-1:0]			TGA_I_SLAVE_NIC;
	wire	[`BUS_TGC_WIDTH-1:0]			TGC_I_SLAVE_NIC;
	wire	[2:0]								CTI_I_SLAVE_NIC;
	wire	[`BUS_DATA_WIDTH-1:0]		DAT_O_SLAVE_NIC;
	wire										ACK_O_SLAVE_NIC;
	wire										RTY_O_SLAVE_NIC;
	wire										ERR_O_SLAVE_NIC;
	wire										STALL_O_SLAVE_NIC;

	//signals for nic_slave(there isn't a master attached so fixed signals)
	reg										CYC_NODE_NIC_I;
	reg										STB_NODE_NIC_I;
	reg	[2:0]								CTI_NODE_NIC_I;
	reg										WE_NODE_NIC_I;
	reg	[`BUS_DATA_WIDTH-1:0]		DAT_NODE_NIC_I;
	reg	[`BUS_ADDRESS_WIDTH-1:0]	ADR_NODE_NIC_I;
	reg	[`BUS_SEL_WIDTH-1:0]			SEL_NODE_NIC_I;
	reg	[`BUS_TGA_WIDTH-1:0]			TGA_NODE_NIC_I;
	reg	[`BUS_TGC_WIDTH-1:0]			TGC_NODE_NIC_I;
	wire	[`BUS_DATA_WIDTH-1:0]		DAT_NODE_NIC_O;
	wire										RTY_NODE_NIC_O;
	wire										ERR_NODE_NIC_O;
	wire										STALL_NODE_NIC_O;
	wire										ACK_NODE_NIC_O;

	//generation of gnt for fake_master
	always @(posedge CYC_O_MASTER_NIC) gnt_wb_i_for_master = 1;
	always @(negedge CYC_O_MASTER_NIC) gnt_wb_i_for_master = 0;

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

		//WB interface
		.CYC_O(CYC_O_MASTER_NIC),
		.STB_O(STB_O_MASTER_NIC),
		.WE_O(WE_O_MASTER_NIC),
		.DAT_O(DAT_O_MASTER_NIC),
		.SEL_O(SEL_O_MASTER_NIC),
		.TGA_O(TGA_O_MASTER_NIC),
		.TGC_O(TGC_O_MASTER_NIC),
		.ADR_O(ADR_O_MASTER_NIC),
		.CTI_O(CTI_O_MASTER_NIC),
		.DAT_I(DAT_I_MASTER_NIC),
		.ACK_I(ACK_I_MASTER_NIC),
		.RTY_I(RTY_I_MASTER_NIC),
		.ERR_I(ERR_I_MASTER_NIC),
		.STALL_I(STALL_I_MASTER_NIC),
	//arbiter interface
		.gnt_wb_i(gnt_wb_i_for_master)
		);

	NIC nic_for_master
		(
		.clk(clk),
		.rst(rst),

		//nic_slave => nic_master link
		.in_link_i(out_link_o_ns_nm),
		.is_valid_i(is_valid_o_ns_nm),
		.credit_signal_o(credit_signal_i_ns_nm),
		.free_signal_o(free_signal_i_ns_nm),
		//nic_master => nic_slave link
		.out_link_o(out_link_o_nm_ns),
		.is_valid_o(is_valid_o_nm_ns),
		.credit_signal_i(credit_signal_i_nm_ns),
		.free_signal_i(free_signal_i_nm_ns),
		//NIC(MASTER) => NODE(SLAVE)
		.DAT_NIC_NODE_I(DAT_NIC_MASTER_NODE_I),
		.ACK_NIC_NODE_I(ACK_NIC_MASTER_NODE_I),
		.RTY_NIC_NODE_I(RTY_NIC_MASTER_NODE_I),
		.ERR_NIC_NODE_I(ERR_NIC_MASTER_NODE_I),
		.STALL_NIC_NODE_I(STALL_NIC_MASTER_NODE_I),
		.CYC_NIC_NODE_O(CYC_NIC_MASTER_NODE_O),
		.STB_NIC_NODE_O(STB_NIC_MASTER_NODE_O),
		.WE_NIC_NODE_O(WE_NIC_MASTER_NODE_O),
		.ADR_NIC_NODE_O(ADR_NIC_MASTER_NODE_O),
		.DAT_NIC_NODE_O(DAT_NIC_MASTER_NODE_O),
		.SEL_NIC_NODE_O(SEL_NIC_MASTER_NODE_O),
		.TGA_NIC_NODE_O(TGA_NIC_MASTER_NODE_O),
		.TGC_NIC_NODE_O(TGC_NIC_MASTER_NODE_O),
		.CTI_NIC_NODE_O(CTI_NIC_MASTER_NODE_O),
		//NODE(MASTER) => NIC(SLAVE)
		.CYC_NODE_NIC_I(CYC_O_MASTER_NIC),
		.STB_NODE_NIC_I(STB_O_MASTER_NIC),
		.CTI_NODE_NIC_I(CTI_O_MASTER_NIC),
		.WE_NODE_NIC_I(WE_O_MASTER_NIC),
		.DAT_NODE_NIC_I(DAT_O_MASTER_NIC),
		.ADR_NODE_NIC_I(ADR_O_MASTER_NIC),
		.SEL_NODE_NIC_I(SEL_O_MASTER_NIC),
		.TGA_NODE_NIC_I(TGA_O_MASTER_NIC),
		.TGC_NODE_NIC_I(TGC_O_MASTER_NIC),
		.DAT_NODE_NIC_O(DAT_I_MASTER_NIC),
		.RTY_NODE_NIC_O(RTY_I_MASTER_NIC),
		.ERR_NODE_NIC_O(ERR_I_MASTER_NIC),
		.STALL_NODE_NIC_O(STALL_I_MASTER_NIC),
		.ACK_NODE_NIC_O(ACK_I_MASTER_NIC),
		//arbiter
		.gnt_wb_i(gnt_wb_i_for_nic_master)
		);

	NIC nic_for_slave
		(
		.clk(clk),
		.rst(rst),

		//nic_master => nic_slave link
		.in_link_i(out_link_o_nm_ns),
		.is_valid_i(is_valid_o_nm_ns),
		.credit_signal_o(credit_signal_i_nm_ns),
		.free_signal_o(free_signal_i_nm_ns),
		//nic_slave => nic_master link
		.out_link_o(out_link_o_ns_nm),
		.is_valid_o(is_valid_o_ns_nm),
		.credit_signal_i(credit_signal_i_ns_nm),
		.free_signal_i(free_signal_i_ns_nm),
		//NIC(MASTER) => NODE(SLAVE)
		.DAT_NIC_NODE_I(DAT_O_SLAVE_NIC),
		.ACK_NIC_NODE_I(ACK_O_SLAVE_NIC),
		.RTY_NIC_NODE_I(RTY_O_SLAVE_NIC),
		.ERR_NIC_NODE_I(ERR_O_SLAVE_NIC),
		.STALL_NIC_NODE_I(STALL_O_SLAVE_NIC),
		.CYC_NIC_NODE_O(CYC_I_SLAVE_NIC),
		.STB_NIC_NODE_O(STB_I_SLAVE_NIC),
		.WE_NIC_NODE_O(WE_I_SLAVE_NIC),
		.ADR_NIC_NODE_O(ADR_I_SLAVE_NIC),
		.DAT_NIC_NODE_O(DAT_I_SLAVE_NIC),
		.SEL_NIC_NODE_O(SEL_I_SLAVE_NIC),
		.TGA_NIC_NODE_O(TGA_I_SLAVE_NIC),
		.TGC_NIC_NODE_O(TGC_I_SLAVE_NIC),
		.CTI_NIC_NODE_O(CTI_I_SLAVE_NIC),
		//NODE(MASTER) => NIC(SLAVE)
		.CYC_NODE_NIC_I(CYC_NODE_NIC_I),
		.STB_NODE_NIC_I(STB_NODE_NIC_I),
		.CTI_NODE_NIC_I(CTI_NODE_NIC_I),
		.WE_NODE_NIC_I(WE_NODE_NIC_I),
		.DAT_NODE_NIC_I(DAT_NODE_NIC_I),
		.ADR_NODE_NIC_I(ADR_NODE_NIC_I),
		.SEL_NODE_NIC_I(SEL_NODE_NIC_I),
		.TGA_NODE_NIC_I(TGA_NODE_NIC_I),
		.TGC_NODE_NIC_I(TGC_NODE_NIC_I),
		.DAT_NODE_NIC_O(DAT_NODE_NIC_O),
		.RTY_NODE_NIC_O(RTY_NODE_NIC_O),
		.ERR_NODE_NIC_O(ERR_NODE_NIC_O),
		.STALL_NODE_NIC_O(STALL_NODE_NIC_O),
		.ACK_NODE_NIC_O(ACK_NODE_NIC_O),
		//arbiter
		.gnt_wb_i(gnt_wb_o_slave_nic)
		);

	fake_slave_pipeline_noBurst
		#(
		.n_wait_cycle_grant(n_wait_cycle_grant),
		.n_wait_cycle_for_read_pipeline(n_wait_cycle_for_read_pipeline),
		.n_wait_cycle_for_write_pipeline(n_wait_cycle_for_write_pipeline),
		.insert_stall(insert_stall),
		.n_wait_cycle_between_read_ack(n_wait_cycle_between_read_ack),
		.n_wait_cycle_between_write_ack(n_wait_cycle_between_write_ack),
		.N_BODY_FLIT(N_BODY_FLIT)
		)
		fake_slave
		(
		.clk(clk),

		//fake arbiter
		.gnt_wb_o(gnt_wb_o_slave_nic),
		//WISHBONE signal
		.CYC_I(CYC_I_SLAVE_NIC),
		.STB_I(STB_I_SLAVE_NIC),
		.WE_I(WE_I_SLAVE_NIC),
		.ADR_I(ADR_I_SLAVE_NIC),
		.DAT_I(DAT_I_SLAVE_NIC),
		.SEL_I(SEL_I_SLAVE_NIC),
		.TGA_I(TGA_I_SLAVE_NIC),
		.TGC_I(TGC_I_SLAVE_NIC),
		.CTI_I(CTI_I_SLAVE_NIC),
		.DAT_O(DAT_O_SLAVE_NIC),
		.ACK_O(ACK_O_SLAVE_NIC),
		.RTY_O(RTY_O_SLAVE_NIC),
		.ERR_O(ERR_O_SLAVE_NIC),
		.STALL_O(STALL_O_SLAVE_NIC)
		);

	initial begin
		clk = 0;
		rst = 1;

		//fixed signals for nic_master since there isn't a slave node connected
		DAT_NIC_MASTER_NODE_I = 0;
		ACK_NIC_MASTER_NODE_I = 0;
		RTY_NIC_MASTER_NODE_I = 0;
		ERR_NIC_MASTER_NODE_I = 0;
		STALL_NIC_MASTER_NODE_I = 0;
		gnt_wb_i_for_nic_master = 0;
		//fixed signals for nic_slave since there isn't a master node connected
		CYC_NODE_NIC_I = 0;
		STB_NODE_NIC_I = 0;
		CTI_NODE_NIC_I = 0;
		WE_NODE_NIC_I = 0;
		DAT_NODE_NIC_I = 0;
		ADR_NODE_NIC_I = 0;
		SEL_NODE_NIC_I = 0;
		TGA_NODE_NIC_I = 0;
		TGC_NODE_NIC_I = 0;
		repeat(2) @(posedge clk);
		rst = 0;
		@(posedge clk);
		repeat(100) @(posedge clk);
		$finish;
	end//initial

endmodule//testbench_master_nic_nic_slave
