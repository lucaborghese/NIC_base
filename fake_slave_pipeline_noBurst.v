//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	fake_slave_pipeline_noBurst 
// Project Name:	NIC_base
// Description:	This module is a generetor of fake signal as a reply for the wb_master_interface module
//						Valid module only in simulation
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"

module fake_slave_pipeline_noBurst
	#(
	parameter n_wait_cycle_grant					=	1,
	parameter n_wait_cycle_for_read_pipeline	=	2,
	parameter n_wait_cycle_for_write_pipeline	=	2,
	parameter insert_stall							=	0,//1: insert random stall, 0: no stall
	parameter n_wait_cycle_between_read_ack	=	0,
	parameter n_wait_cycle_between_write_ack	=	0,
	parameter N_BODY_FLIT							=	`MAX_PACKET_LENGHT-2
	)
	(
	input																	clk,
//	input																	rst,//if you take CYC_I low for one cycle the module will reset

	//arbiter
	output	reg														gnt_wb_o,

	//input from the WISHBONE
	input																	CYC_I,
	input																	STB_I,
	input																	WE_I,
	input				[`BUS_ADDRESS_WIDTH-1:0]					ADR_I,
	input				[`BUS_DATA_WIDTH-1:0]						DAT_I,
	input				[(`BUS_DATA_WIDTH/`GRANULARITY)-1:0]	SEL_I,
	input				[2:0]												CTI_I,

	//output on the WISHBONE
	output	reg	[`BUS_DATA_WIDTH-1:0]						DAT_O,
	output	reg														ACK_O,
	output	reg														RTY_O,
	output	reg														ERR_O,
	output	reg														STALL_O
	);

	genvar i;

	integer	count_n_of_reply;
	integer	count_n_of_ack;
	integer	waiting_grant;
	integer	waiting_pipeline;
	integer	waiting_between_read;
	integer	waiting_between_write;

	//reply for a read request
	reg [`FLIT_WIDTH-`N_BITS_FLIT_TYPE-`N_BITS_FLIT_VNET_ID-1:0] random_chunk;
	reg [`MAX_BURST_LENGHT*`BUS_DATA_WIDTH-1:0] read_message_reply;
	wire [`BUS_DATA_WIDTH-1:0] reply_read[`MAX_BURST_LENGHT-1:0];
	reg [`N_BITS_FLIT_VNET_ID-1:0] vnet;
	generate
		for( i=0; i<`MAX_BURST_LENGHT ; i=i+1 ) begin : reply_generation
			assign reply_read[i] = read_message_reply[(i+1)*`BUS_DATA_WIDTH-1:i*`BUS_DATA_WIDTH];
		end
	endgenerate

	//storing data of a write
	reg [`BUS_DATA_WIDTH-1:0] data_r[`MAX_BURST_LENGHT-1:0];
	reg [`BUS_ADDRESS_WIDTH-1:0] address_r;

	initial begin
		gnt_wb_o = 0;
		DAT_O = 0;
		ACK_O = 0;
		RTY_O = 0;
		ERR_O = 0;
		STALL_O = 0;
		count_n_of_reply = 0;
		count_n_of_ack = 0;
		waiting_grant = 0;
		waiting_pipeline = 0;
		waiting_between_read = 0;
		waiting_between_write = 0;
	end

	always @(posedge CYC_I) begin//WISHBONE arbitration begin

		vnet = $random;
		random_chunk = $random;
		read_message_reply = { random_chunk , vnet, `TAIL_FLIT , {N_BODY_FLIT{random_chunk , vnet , `BODY_FLIT}} , random_chunk , vnet , `HEAD_FLIT };
		waiting_grant = 1;
		repeat(n_wait_cycle_grant+1) @(posedge clk);
		waiting_grant = 0;
		gnt_wb_o = 1;
		waiting_pipeline = 1;
		if(WE_I) begin//write transaction
			repeat(n_wait_cycle_for_write_pipeline+1) @(posedge clk);
		end else begin//read transaction
			repeat(n_wait_cycle_for_read_pipeline+1) @(posedge clk);
		end//else if(WE_I)
		waiting_pipeline = 0;
	end//always

	//do i have to reply?
	always @(posedge clk) begin
		if(CYC_I) begin
			if(waiting_between_read || waiting_between_write) begin
				ACK_O = 0;
				if(WE_I) begin
					waiting_between_write = waiting_between_write - 1;
				end else begin
					waiting_between_read = waiting_between_read - 1;
				end//else if(WE_I)
			end else begin
				if(!waiting_grant && !waiting_pipeline && count_n_of_ack<count_n_of_reply) begin
					count_n_of_ack = count_n_of_ack + 1;
					ACK_O = 1;
					if(WE_I) begin
						waiting_between_write = n_wait_cycle_between_write_ack;
					end else begin
						DAT_O = reply_read[count_n_of_ack-1];
						waiting_between_read = n_wait_cycle_between_read_ack;
					end//else if(WE_I)
				end else begin
					ACK_O = 0;
				end//else if(!waiting_pipeline && count_n_of_ack<count_n_of_reply)
			end//else if(waiting_between_read || waiting_between_write)
		end else begin
			ACK_O = 0;
			count_n_of_ack = 0;
			waiting_between_read = 0;
			waiting_between_write = 0;
		end//else if(CYC_O)
	end//always

	//counting number of reply that we have to generate
	always @(posedge clk) begin
		if(CYC_I) begin
			if(STB_I && !STALL_O) begin
				if(count_n_of_reply==0) begin//storing the address only if it is the first chunk
					address_r = ADR_I;
					read_message_reply[`SRC_BITS_HEAD_FLIT] = address_r[`DEST_BITS_HEAD_FLIT];
					read_message_reply[`DEST_BITS_HEAD_FLIT] = address_r[`SRC_BITS_HEAD_FLIT];
//					read_message_reply[`CMD_BITS_HEAD_FLIT] = 0;
				end
				if(WE_I) begin//if write store data
					data_r[count_n_of_reply] = DAT_I;
				end
				count_n_of_reply = count_n_of_reply + 1;
			end
		end else begin
			count_n_of_reply = 0;
		end
	end//always

	//insert random stall
	always @(posedge clk) begin
		if(insert_stall) begin
			STALL_O = $random;
		end else begin
			STALL_O = 0;
		end//else if(insert_stall)
	end//always

	//tolgo il gnt
	always @(negedge CYC_I) begin
		gnt_wb_o <= 0;
		if(address_r[`CMD_BITS_HEAD_FLIT]==0) begin
			$display ("[FAKE_WB_SLAVE] %g Received address %h and data %h from source %d for %d with command %b",$time,address_r,data_r,address_r[`SRC_BITS_HEAD_FLIT],address_r[`DEST_BITS_HEAD_FLIT],address_r[`CMD_BITS_HEAD_FLIT]);
		end else begin
			$display ("[FAKE_WB_SLAVE] %g Received read request %h from %d to %d with command %b",$time,address_r,address_r[`SRC_BITS_HEAD_FLIT],address_r[`DEST_BITS_HEAD_FLIT],address_r[`CMD_BITS_HEAD_FLIT]);
			$display ("[FAKE_WB_SLAVE] %g Injected reply data %h from source %d for %d with command %b",$time,reply_read,reply_read[0][`SRC_BITS_HEAD_FLIT],reply_read[0][`DEST_BITS_HEAD_FLIT],reply_read[0][`CMD_BITS_HEAD_FLIT]);
		end
//		if(count_n_of_ack<count_n_of_reply) begin
//			ERR_O = 1;
//			@(posedge clk);
//			ERR_O = 0;
//		end
	end//always

endmodule//fake_slave_pipeline_noBurst
