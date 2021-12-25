/* Parameterized FIFO */
`default_nettype none
`timescale 1ns/1ns
module sync_fifo 
	#(	parameter 	FIFO_WIDTH		= 32,
	 	parameter	FIFO_DEPTH		= 4
	)

	(
		input							reset,
		input							clk,
		input							read_en,
		input							write_en,
		input [FIFO_WIDTH-1:0]			din,

		output [FIFO_WIDTH-1:0]			dout,
		output  						fifo_full,
		output 							fifo_empty
		


	);


	/* Words in FIFO */
	reg [$clog2(FIFO_DEPTH)-1:0] counter;

	/* Actual FIFO */
	reg [FIFO_WIDTH-1:0] buffer[FIFO_DEPTH-1:0];

	/* Read and write pointers */
	reg [$clog2(FIFO_DEPTH)-1:0] readptr;
	reg [$clog2(FIFO_DEPTH)-1:0] writeptr;


	assign fifo_full 	= (counter == FIFO_DEPTH-1);
	assign fifo_empty 	= (counter == 0);

//	assign dout =  (!fifo_empty) ? buffer[readptr] : 0;
	assign dout =  buffer[readptr];

	/* Special for parameterized reset of buffer */
	integer i;


	always @( posedge clk or posedge reset ) begin

			if( reset ) begin
				for( i = 0; i < FIFO_DEPTH; i = i + 1) begin: fifo_buffer_reset
					buffer[i] <= 0;
				end

  				writeptr <= 0;
  				readptr <= 0;
			//	dout <= 0;
				counter <= 0;
			end
			else begin

				/* Write condition */
				if( write_en ) begin
					buffer[writeptr] <= din;
					writeptr <= writeptr + 1;
				end
	
				/* Read Condition */
				if ( read_en ) begin
			//		dout <= buffer[readptr];
					readptr <= readptr + 1;
				end
	
				/* Counter handling */
				if ( read_en && write_en ) begin
					/* If reading and writing, need to handle race condition
					* so it's easier to just not do any operation */
					counter <= counter;
				end
				else if( !fifo_full && write_en && !read_en ) begin
					/* Add to counter if not full, and not reading */
					counter <= counter + 1;
				end
				else if( !fifo_empty && !write_en && read_en ) begin
					/* Subtract value from counter if reading, and not writing */
					counter <= counter - 1;
					buffer[readptr] <= 0;
				end
			end

	end

	/* Formal Verification */
	`ifdef FORMAL
	reg past_available = 0;
	initial begin
		assume(reset);
	end
	always @(posedge clk) begin
		/* Assumption for input data */
		assume(din != 0);

		/* Assume that read and write doesn't happen at the same time as the
		* reset signal */
	   	if( reset == 1 ) begin
			assume( read_en == 0 );
			assume( write_en == 0 );
		end

		/* First clock, so past function becomes possible to use*/
		past_available <= 1;


		if( past_available && $past(reset) && !reset) begin
			assume( read_en == 0 );
			assume( write_en == 0 );

			_reset_readptr_:assert(readptr == 0);
			_reset_writetr_:assert(writeptr== 0);
			for( i = 0; i < FIFO_DEPTH; i = i + 1) begin
				assert(	buffer[i] == FIFO_WIDTH'b0);
			end
		end
		if( past_available && !$past(reset) ) begin
//			assume(!reset);&& !reset
			assume(din != $past(din));

			/* Assume that read and write doesn't immediately after the
			* reset signal */
		   	if( $past(reset) == 1 ) begin
				assume( read_en == 0 );
				assume( write_en == 0 );
			end

			/* Asserts */

			/* Check that write works */
			if( !write_en && $past(write_en) && !reset ) begin
				_writeen_:assert(buffer[$past(writeptr)] == $past(din) );
			end

			/* Check that read works */
//			if( !read_en && $past(read_en) && !$past(reset) ) begin
//				_readen_:assert(buffer[$past(readptr)]== $past(dout) );
//			end
			if( read_en ) begin
				_readen_:assert( buffer[readptr] == dout);
			end

			/* Check that pointers wrap around */
			_writeptr_:assert( writeptr < FIFO_DEPTH);
			_readptr_:assert( readptr  < FIFO_DEPTH);


			/* Check that counters function as intended */
		
			/* No change to counter */
			if( (!read_en && $past(read_en)) && !write_en && $past(write_en) && !reset )begin
				_rwcounter_:assert( counter == $past(counter) );
			end
			if( (!read_en && $past(read_en)) && !write_en && $past(!write_en) && $past(!fifo_empty) && !reset )begin
				_deccounter_:assert( counter == $past(counter - 1) );
			end
			if( (!read_en && $past(!read_en)) && !write_en && $past(write_en) && $past(!fifo_full) && !reset )begin
				_inccounter_:assert( counter == $past(counter + 1) );
			end



			/* Covers */

			
		end



	end
	`endif
		


endmodule
