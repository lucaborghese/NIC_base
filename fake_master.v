//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	fake_master 
// Project Name:	NIC_base 
// Description:	fake master interface connected to the WISHBONE bus
//
//////////////////////////////////////////////////////////////////////////////////
`include "NIC-defines.v"

module fake_master
	#(
	parameter MORE_READ						=	0,//0 more write, 1 more read(see also HOW_MANY_MORE_READ/WRITE)
	parameter MORE_SMALL_WRITE				=	0,//0 more big write, 1 more small write(see also HOW_MANY_MORE_SMALL)
	parameter HOW_MANY_MORE_READ			=	0,//greater this number greater the probability to have more read/write than write/read
	parameter HOW_MANY_MORE_SMALL			=	0,//greater this number greater the probability to have more small/big write than big/small
	parameter N_BODY_FLIT					=	`MAX_PACKET_LENGHT-2
	)
	(
	input	clk,
	input rst,

	//WISHBONE interface
	output	reg									CYC_O,
	output	reg									STB_O,
	output											WE_O,
	output		[`BUS_DATA_WIDTH-1:0]		DAT_O,
	output		[`BUS_SEL_WIDTH-1:0]			SEL_O,
	output		[`BUS_ADDRESS_WIDTH-1:0]	ADR_O,
	output		[2:0]								CTI_O,
	input			[`BUS_DATA_WIDTH-1:0]		DAT_I,
	input												ACK_I,
	input												RTY_I,
	input												ERR_I,
	input												STALL_I,
	//arbiter interface
	input	gnt_wb_i
	);

	`include "NIC_utils.vh"

	genvar i;

	assign SEL_O = ~0;
	assign WE_O = ~read;
	assign ADR_O = address;
	assign DAT_O = data[count_n_of_wb_cycle];
	assign CTI_O = 0;

	wire [`BUS_ADDRESS_WIDTH-1:0] address;
	reg [`BUS_DATA_WIDTH*`MAX_BURST_LENGHT-1:0] message;
	reg [`N_BITS_FLIT_VNET_ID-1:0] vnet;
	wire [`BUS_DATA_WIDTH-1:0] data[`MAX_BURST_LENGHT-1:0];

	assign address = data[0][`BUS_ADDRESS_WIDTH-1:0];

	generate
		for( i=0 ; i<`MAX_BURST_LENGHT ; i=i+1 ) begin : data_computation
			assign data[i] = message[(i+1)*`BUS_DATA_WIDTH-1:i*`BUS_DATA_WIDTH];
		end//for
	endgenerate

	reg [`BUS_DATA_WIDTH-1:0] read_reply[`MAX_BURST_LENGHT-1:0];

	//Decide if the next message is a read or a write(random) and if it is a write if is a big or a little message.
	reg read;
	reg small_write;
	reg [`FLIT_WIDTH-`N_BITS_FLIT_TYPE-`N_BITS_FLIT_VNET_ID-1:0] random_chunk;
	always @(posedge CYC_O) begin
		read = $random;
		repeat(HOW_MANY_MORE_READ) begin
			if(read!=MORE_READ) begin
				read = $random;
			end//if
		end//repeat
		small_write = $random;
		repeat(HOW_MANY_MORE_SMALL) begin
			if(small_write!=MORE_SMALL_WRITE) begin
				small_write = $random;
			end//if
		end//repeat

		//message generation
		n_of_wb_cycle = `MAX_BURST_LENGHT;
		random_chunk = $random;
		vnet = $random;
		message = 0;
		case(read)
			1: begin//read generation
				message[`FLIT_WIDTH-1:0] = $random;
				message[`FLIT_TYPE_BITS] = `HEAD_TAIL_FLIT;
				message[`FLIT_VNET_ID_BITS] = vnet;
				message[`CMD_BITS_HEAD_FLIT] = 1;//read if cmd is !=0
				$display("[FAKE_MASTER] %g Injecting read command address %h from %d to %d",$time,message[`FLIT_WIDTH-1:0],message[`SRC_BITS_HEAD_FLIT],message[`DEST_BITS_HEAD_FLIT]);
			end
			default: begin//write generation
				case(small_write)
					1: begin//small write
						n_of_wb_cycle = 1;
						message[`FLIT_WIDTH-1:0] = $random;
						message[`FLIT_TYPE_BITS] = `HEAD_TAIL_FLIT;
						message[`FLIT_VNET_ID_BITS] = vnet;
						message[`CMD_BITS_HEAD_FLIT] = 0;//write if cmd!=0
					end
					default: begin//big write
						message = { random_chunk , vnet, `TAIL_FLIT , {N_BODY_FLIT{random_chunk , vnet , `BODY_FLIT}} , random_chunk , vnet , `HEAD_FLIT };
					end
				endcase
			end
		endcase
	end

	//receiving ack
	always @(posedge clk) begin
		if(ACK_I) begin
			read_reply[count_n_of_ack] <= DAT_I;
			count_n_of_ack <= count_n_of_ack + 1;
		end
	end

	integer	n_of_wb_cycle;
	integer	count_n_of_wb_cycle;
	integer	count_n_of_ack;
	integer	transmitting;

	initial begin
		transmitting = 0;
		count_n_of_wb_cycle = 0;
		count_n_of_ack = 0;
	end

	//FSM
	localparam IDLE			=	2'b00;
	localparam WAIT_GRANT	=	2'b01;
	localparam TRANSMITTING	=	2'b10;
	localparam WAITING_ACK	=	2'b11;
	reg [1:0] state;
	reg [1:0] next_state;

	//update state
	always @(posedge clk) begin
		if(rst) begin
			state <= IDLE;
		end else begin
			state <= next_state;
		end
	end//always

	//computation of next_state
	always @(*) begin
		case(state)
			IDLE: begin
				CYC_O = 0;
				count_n_of_wb_cycle = 0;
				count_n_of_ack = 0;
				next_state = WAIT_GRANT;
			end//IDLE

			WAIT_GRANT: begin
				CYC_O = 1;
				if(gnt_wb_i) begin
					next_state = TRANSMITTING;
				end else begin
					next_state = WAIT_GRANT;
				end
			end//WAIT_GRANT

			TRANSMITTING: begin
				CYC_O = 1;
				if(count_n_of_wb_cycle==n_of_wb_cycle-1 && STB_O && !STALL_I) begin
					next_state = WAITING_ACK;
				end else begin
					next_state = TRANSMITTING;
				end
			end//TRANSMITTING

			WAITING_ACK: begin
				CYC_O = 1;
				if(count_n_of_ack==n_of_wb_cycle) begin
					next_state = IDLE;
				end else begin
					next_state = WAITING_ACK;
				end
			end//WAITING_ACK
		endcase
	end//always
	//end FSM

	//sending message
	always @(*) begin
		if(state==TRANSMITTING && !STALL_I) begin
			STB_O = 1;
		end else begin
			STB_O = 0;
		end
	end

	//update of count_n_of_wb_cycle
	always @(posedge clk) begin
		if(STB_O) begin
			count_n_of_wb_cycle <= count_n_of_wb_cycle + 1;
		end else begin
			count_n_of_wb_cycle <= count_n_of_wb_cycle;
		end
	end

	//log
	always @(negedge CYC_O) begin
		if(WE_O) begin
			$display("[FAKE_MASTER] %g Injected address %h and data %h from source %d for %d with command %b",$time,address,data,data[0][`SRC_BITS_HEAD_FLIT],data[0][`DEST_BITS_HEAD_FLIT],data[0][`CMD_BITS_HEAD_FLIT]);
		end else begin
			$display("[FAKE_MASTER] %g Received reply data %h from %d for %d",$time,read_reply,read_reply[0][`SRC_BITS_HEAD_FLIT],read_reply[0][`DEST_BITS_HEAD_FLIT]);
		end
	end

endmodule
