//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	msg_to_pkt 
// Project Name:	NIC_base
// Description:	It takes as input a WB bus message and as output produce a pkt
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"

module msg_to_pkt
	(
	input				[`MAX_BURST_LENGHT*`BUS_DATA_WIDTH-1:0]	data_i,
	input				[`BUS_ADDRESS_WIDTH-1:0]						address_i,
	input				[`MAX_BURST_LENGHT*`BUS_SEL_WIDTH-1:0]		sel_i,
	output	reg	[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]		pkt_o
	);

	//computation of pkt_o

endmodule//msg_to_pkt
