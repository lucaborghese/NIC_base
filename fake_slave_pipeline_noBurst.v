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
	parameter	n_wait_cycle_grant					=	1,
	parameter	n_wait_cycle_for_read_pipeline	=	2,
	parameter	n_wait_cycle_for_write_pipeline	=	2,
	parameter	insert_stall							=	0,//1: insert random stall, 0: no stall
	parameter	n_wait_cycle_between_read_ack		=	0,
	parameter	n_wait_cycle_between_write_ack	=	0
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

	integer	count_n_of_reply;
	integer	count_n_of_ack;
	integer	waiting_grant;
	integer	waiting_pipeline;
	integer	waiting_between_read;
	integer	waiting_between_write;

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
						DAT_O = $random;
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
				//HERE I CAN SAVE ADR_I E DAT_I FOR INTEGRITY CHECK
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
		gnt_wb_o = 0;
		if(count_n_of_ack<count_n_of_reply) begin
			ERR_O = 1;
			@(posedge clk);
			ERR_O = 0;
		end
	end//always

endmodule//fake_slave_pipeline_noBurst
