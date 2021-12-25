/* Parallel Load Shift Register */
`default_nettype none
`timescale 1ns/1ns
module pload_shift #(
		parameter LOAD_WIDTH = 32,
		parameter OUT_WIDTH = 8
	)(
		input 						clk,
		input						reset,
		input[LOAD_WIDTH-1:0]		din,
		input						enable,	/* Trigger to start operation to write out */

		output reg [OUT_WIDTH-1:0]	dout,
		output reg					busy	
	);

	/* Statemachine values */
	`define OP_IDLE		0
	`define OP_WRITE	1
	reg [1:0] op;

	/* Required calculation to get correct number of stages for entire width
	* parallel load */
//	reg [OUT_WIDTH-1:0]  data [((LOAD_WIDTH >> $clog2(8)) - 1):0 ];
	reg [7:0] data [3:0];

	/* Counter for how many bytes are left to shift out */
	reg [ ((LOAD_WIDTH >> $clog2(8)) - 1) : 0] dcount;

	always @(posedge clk or posedge reset ) begin
		if( reset ) begin
			op <= `OP_IDLE;
			data[0] <= 0;
			data[1] <= 0;
			data[2] <= 0;
			data[3] <= 0;
			busy <= 0;
			dout <= 0;
			dcount <= 3;
		end
		else begin
			if( op == `OP_IDLE && !enable ) begin
				busy <= 1'b0;
				dout <= 0;
			end
			else if( (op == `OP_IDLE) && enable ) begin
				op <= `OP_WRITE;
				dcount <= (LOAD_WIDTH >> $clog2(8)) - 1;
				data[0] <= din[7:0];
				data[1] <= din[15:8];
				data[2] <= din[23:16];
				data[3] <= din[31:24];
				/* store the rest of din for later */
			end
			else if((op == `OP_WRITE) && (dcount != 0)) begin
				busy <= 1'b1;
				data[0] <= 0;
				data[1] <= data[0];
				data[2] <= data[1];
				data[3] <= data[2];
				dout<= data[3]; 
				dcount <= dcount - 1;
			end
			else if( (op == `OP_WRITE) && (dcount == 0) ) begin
				data[0] <= 0;
				data[1] <= data[0];
				data[2] <= data[1];
				data[3] <= data[2];
				dout<= data[3]; 
				op <= `OP_IDLE;
			end
		end
	end

endmodule
