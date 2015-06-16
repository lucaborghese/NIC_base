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
	input				[`BUS_TGA_WIDTH-1:0]								tga_i,
	input				[`BUS_TGC_WIDTH-1:0]								tgc_i,
	input																		WE_I,
	input																		reply_for_wb_master_interface_i,
	input																		r_msg2pkt_i,//if high, pkt_o must be computed from the signals above
	output	reg	[`MAX_PACKET_LENGHT*`FLIT_WIDTH-1:0]		pkt_o
	);

	//computation of pkt_o
	always @(*) begin
		pkt_o = 0;
		if(r_msg2pkt_i) begin
			pkt_o = data_i;
			if(!WE_I && !reply_for_wb_master_interface_i) begin//if read
				pkt_o[`HEAD_FLIT_ADDRESS_BITS] = address_i;
				pkt_o[`SRC_BITS_HEAD_FLIT] = tga_i;
				pkt_o[`CMD_BITS_HEAD_FLIT] = tgc_i;
			end//if
		end//if(r_msg2pkt_i)
	end//always

endmodule//msg_to_pkt
