/* RAID0 */
`default_nettype none
`timescale 1ns/1ns

module raid0 
	#(	parameter NDRIVES = 4,
		parameter DWIDTHHOST = 32,
		parameter ADDRWIDTHHOST = 32,
		parameter DWIDTHDEVICE = 32,
		parameter ADDRWIDTHDEVICE = 32
	)(
		/* Host connection */
		input											reset,
		input											clk,
		input											read_en,
		input											write_en,
		input 		[DWIDTHHOST-1:0]					host_din,
		input 		[ADDRWIDTHHOST-1:0]					host_addr_in,
		output reg	[DWIDTHHOST-1:0]					host_dout,
		output reg										busy,

		/* Drive connections */
		input 		[NDRIVES-1:0]						drive_busy,
		input		[(DWIDTHDEVICE*NDEVICES)-1:0]		drive_din,

		output reg	[(DWIDTHDEVICE*NDEVICES)-1:0] 		drive_dout,
		output reg	[(ADDRWIDTHDEVICE*NDEVICES)-1:0] 	drive_addr_out,
		output reg	[NDRIVES-1:0]						w_out,
		output reg	[NDRIVES-1:0]						r_out

	);

	/* RAID0 is data striping
	* on writes, need to send data out to each output*/

   	/* States for writing data to devices */
	`define W_SPLIT_WRITE		0
	`define W_WAIT_BUSY			1
	`define W_DONE				2
	reg [1:0] write_state;

	/* States for reading data */
	`define R_DEVICE_READ		0
	`define R_WAIT_BUSY			1
	`define R_HOST_WB			2
	reg [1:0] read_state;	
	
	/* Temporary storgae registers for data */
	reg [ADDRWIDTHHOST-1:0] addr;
	reg [DWIDTHHOST-1:0] 	data;


   	integer i;
	always @(posedge clk or posedge reset ) begin
		if( reset ) begin
			busy <= 1'b0;
			host_dout <= 0;
			drive_dout <= 0;
			drive_addr_out <= 0;
			w_out <= 0;
			r_out <= 0;
		end
		else begin 

			/* Start Read State Machine */
			if( read_en && !busy) begin
				write_state <= `W_SPLIT_WRITE;	/* Reset Write state */

				addr <= host_addr_in;
			end

			/* Start Write State Machine */
			else if( write_en && !busy ) begin
				read_state <= `R_DEVICE_READ;	/* Reset Read state */

				data <= host_din;
				addr <= host_addr_in;

			end
			else if (busy) begin
				/* check state machines */

				/* write state machine */
				case ( write_state ) begin
					
					`W_SPLIT_WRITE: begin
						busy <= 1'b1; /* set busy status */
						/* split up data into n devies, copy same address to all */
						for( i = 0; i < NDRIVES; i = i + 1) begin
							drive_addr_out[i] <= addr;
							drive_dout[i] <= data[ (`SPLITWIDTH * i+1)-1:(`SPLITWIDTH * i) ];
						end

						write_state <= `W_WAIT_BUSY;
					end
					`W_WAIT_BUSY: begin
						/* Wait until all drives are not busy */
						if(  &drive_busy ) begin
							write_state = `W_DONE;
						end

					end

					`W_DONE: begin
						write_state = `W_GET_ADDR;
						busy <= 1'b0;
					end

				endcase

				/* read state machine */

			end


		end
	end

	`ifdef FORMAL
	always @(clk) begin

	end

	`endif
endmodule
