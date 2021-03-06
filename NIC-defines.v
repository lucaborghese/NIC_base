//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	NIC-defines 
// Project Name:	NIC_base 
// Description:	Constant values, defines, used for the project
//
//////////////////////////////////////////////////////////////////////////////////

//INPUT PORT
`define	MAX_CREDIT	10
`define	N_OF_VC		2
`define	N_OF_VN		2

//POSSIBLE FLIT TYPE
`define	HEAD_FLIT		2'b00
`define	BODY_FLIT		2'b01
`define	TAIL_FLIT		2'b10
`define	HEAD_TAIL_FLIT	2'b11

//FLIT INFORMATION
`define	FLIT_WIDTH			16//flit width in bit
`define	FLIT_TYPE_BITS		1:0//bits of the flit where can be found the flit_type information
`define	N_BITS_FLIT_TYPE	2//number of wire where can be found the flit_type information

`define	FLIT_VNET_ID_BITS					2
`define	N_BITS_FLIT_VNET_ID				1
`define	FLIT_VC_ID_BITS					3
`define	N_BITS_FLIT_VC_ID					1
//HEAD(TAIL) FLIT INFORMATION
`define	ROUTING_INFORMATION_BITS		19:10
`define	N_BITS_ROUTING_INFORMATION		10
`define	CMD_BITS_HEAD_FLIT				11:10
`define	N_BIT_CMD_HEAD_FLIT				2
`define	SRC_BITS_HEAD_FLIT				13:12
`define	N_BIT_SRC_HEAD_FLIT				2
`define	DEST_BITS_HEAD_FLIT				15:14
`define	N_BIT_DEST_HEAD_FLIT				2
`define	HEAD_FLIT_ADDRESS_BITS			15:8

//PACKET INFORMATION
`define	CACHE_LINE_WIDTH	64
`define	MAX_PACKET_LENGHT	((`CACHE_LINE_WIDTH/`FLIT_WIDTH)+1)//max packet lenght head included in flit

//PACKET2MESSAGE STAGE
`define	QUEUE_WIDTH	8//size of the queue in message(1 message = `MAX_PACKET_LENGHT*`FLIT_WIDTH bit)

//WISHBONE BUS PROPERTIES
`define	BUS_DATA_WIDTH		32//in bit
`define	BUS_ADDRESS_WIDTH	16//in bit
`define	GRANULARITY			8//granularity of data over dat_o in bit, SEL_O width = BUS_DATA_WIDTH / GRANULARITY
`define	MAX_BURST_LENGHT	3//(`MAX_PACKET_LENGHT*`FLIT_WIDTH)/`BUS_DATA_WIDTH
`define	BUS_SEL_WIDTH		`BUS_DATA_WIDTH/`GRANULARITY
//CTI signal(cycle type identifier)
`define	CTI_CLASSIC_CYCLE						3'b000
`define	CTI_CONSTANT_ADDRESS_BURST_CYCLE	3'b001
`define	CTI_END_OF_BURST						3'b111

//table of on the fly transaction from Node to NoC
`define	TABLE_PENDING_NODE2NOC_WIDTH		4

//FIFO
`define	N_FIFO_OUT_BUFFER	6
