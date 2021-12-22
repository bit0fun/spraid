/* RAID0 Write Module */
`default_nettype none
`timescale 1ns/1ns

module raid0_write
	#(	parameter NDEVICE = 8,
		parameter DWIDTHHOST = 32,
		parameter ADDRWIDTHHOST = 32,
		parameter DWIDTHDEVICE = 8
//		parameter ADDRWIDTHDEVICE = 32
	)(
		input										reset,
		input										enable,
		input										clk,
		input	[DWIDTHHOST-1:0]		 			host_data,
		input	[ADDRWIDTHHOST-1:0]					host_addr,

		/* Output one wide bus for each device, parse at top level to each */
		output reg	[(NDEVICE*DWIDTHDEVICE)-1:0]	device_data,
		output reg	[(ADDRWIDTHHOST)-1:0]			device_addr,

		/* Tell devices that it is time to read data */
		output reg									device_write,
	
		/* Busy signals */
		input	[NDEVICE-1:0]						device_busy,
		output reg									busy


	);

	/* State definitions */
	`define IDLE		0
	`define FILL_QUEUE	1
	`define WRITE_DEV	2
	`define WAIT_DBUSY	3
	reg [2:0] state;

	/* Buffer to store data information */
	/* Equation scales the number of entries to always fit the correct amount
	* of buffer lines */
	reg [DWIDTHHOST-1:0]		dbuf [((NDEVICE * DWIDTHDEVICE )/DWIDTHHOST)-1:0];
	reg [ADDRWIDTHHOST-1:0]		addrbuf [((NDEVICE * DWIDTHDEVICE )/DWIDTHHOST)-1:0];
	reg [$clog2(NDEVICE)-1:0]	queue_cnt;

	wire [(NDEVICE*DWIDTHDEVICE)-1:0]	device_data_w;

	genvar x, y;
	generate
	for( x = 0; x < ((NDEVICE * DWIDTHDEVICE )/DWIDTHHOST); x = x + 1) begin
		for ( y = 0; y < NDEVICE; y = y + 1 ) begin
			/* Grab specific bits for each device */
			assign device_data_w[ (DWIDTHDEVICE*(y + 1))-1:(DWIDTHDEVICE*(y)) ] = dbuf[x][ (DWIDTHDEVICE*(y + 1))-1:(DWIDTHDEVICE*(y)) ];
		end
	end
	endgenerate


	integer i;

	always @( posedge clk or posedge reset) begin
		/* Clear out registers */
		if( reset ) begin
			device_data <= 0;
			device_addr <= 0;
			state <= `IDLE;
			queue_cnt <= 0;
			device_write <= 0;
			busy <= 0;
			for( i = 0; i < ((NDEVICE * DWIDTHDEVICE)/DWIDTHHOST); i = i + 1) begin
				addrbuf[i] <= 0;
				dbuf[i] <= 0;
			end


		end
		else begin

			case (state)

				`IDLE: begin
					/* Start to read in data */
					if( enable ) begin
						state <= `FILL_QUEUE;
						dbuf[queue_cnt] <= host_data;
						addrbuf[queue_cnt] <= host_addr;
						queue_cnt <= queue_cnt + 1;
					end
				end

				`FILL_QUEUE: begin

					/* If the number of queue elements equals the number of
					* devices (minus one), then go write out the data */
					if(queue_cnt == (NDEVICE - 1)) begin
						state <= `WRITE_DEV;
						busy <= 1'b1;
					end
					/* If disable happens at any time, go back to idle and
					* reset everything for good measure */
				   	else if( !enable ) begin
						state <= `IDLE;
						device_data <= 0;
						device_addr <= 0;
						queue_cnt <= 0;
						device_write <= 0;
						busy <= 0;
						for( i = 0; i < ((NDEVICE * DWIDTHDEVICE)/DWIDTHHOST); i = i + 1) begin
							addrbuf[i] <= 0;
							dbuf[i] <= 0;
						end

					end
					/* Otherwise, continue collecting data */
					else begin
						dbuf[queue_cnt] <= host_data;
						addrbuf[queue_cnt] <= host_addr;
						queue_cnt <= queue_cnt + 1;
					end

				end

				`WRITE_DEV: begin
					/* Write out data to the registers */
					device_data = device_data_w;

					/* Use the same address for all data */
					device_addr <= addrbuf[0];
					
					/* Switch to next state */
					state <= `WAIT_DBUSY;

				end

				`WAIT_DBUSY: begin
					if( device_busy == 0 ) begin
						/* Devices are no longer busy, go back to idle */
						busy <= 0;
						state = `IDLE;
						device_write <= 0;
						queue_cnt <= 0;
						device_data <= 0;
						device_addr <= 0;
					end
				end

			endcase

		end

	end

	/* Formal Verification */
	`ifdef FORMAL
	reg past_available = 0;
	initial begin
		assume(reset);
	end
	always @(posedge clk) begin

		assume(host_data != 0);
		assume(host_addr != 0);
		if( reset ) begin
			assert(device_data == 0);
			assert(state == `IDLE);
			assert(device_data== 0);
			assert(device_addr == 0);
			assert(queue_cnt == 0);
			assert(device_write == 0);
			for( i = 0; i < ((NDEVICE * DWIDTHDEVICE)/DWIDTHHOST); i = i + 1) begin
				assert(addrbuf[i] == 0);
				assert(dbuf[i] == 0);
			end
		end

		/* First clock, past function becomes available to use */
		if( past_available && $past(reset) && !reset)begin
			assume(host_data != $past(host_data));
			assume(host_addr != $past(host_addr));

			/* check state transitions */
			case (state)
				`IDLE: begin 
					assume(enable);
					/* Can only be reached from reset, reset during fill queue, or from wait dbusy*/
					assert( $past(reset) || (($past(state) == `FILL_QUEUE) && $past(reset)) || ($past(state) == `WAIT_DBUSY));
				end
				`FILL_QUEUE: begin
					assume(enable);
					assert( ($past(state) == `IDLE) && enable && $past(enable) );
				end
				`WRITE_DEV: begin
					assert( $past(state) == `FILL_QUEUE && (queue_cnt == (NDEVICE - 1)) );
				end
				`WAIT_DBUSY: begin
					assert( $past(state) == `WRITE_DEV );
				end
				

			endcase

		end

	end
	`endif

endmodule 
