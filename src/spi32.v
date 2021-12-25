/* 32 bit SPI Peripheral */
`default_nettype none
`timescale 1ns/1ns
module spi32 (
		input				reset,
		input				clk,

		input				read,
		input				write,

		input  [31:0]		din,
		output [31:0]		dout,

		/* Get size for command */

		/* Busy signal for higher level control */
		output reg			busy,

		/* SPI interface */
		input				sdi,
		output  			sdo,
		output				clk_out,
		output reg			cs

	);

	/* Statemachine definitons */
	`define SPI_IDLE			0
	`define SPI_WRITE_FIFO		1
	`define SPI_WRITE_OUT		2
	`define SPI_START_READ_FIFO	3
	`define SPI_READ_OUT		4
	reg [3:0] spi_state;

	/* State for writing */
	`define SPI_WRITE_START		0
	`define SPI_WAIT_READY 		1
	`define SPI_ENABLE_WRITE	2
	`define SPI_WRITE_LAST_BYTE	3
	`define SPI_WRITE_FINISH	4
	reg [2:0] write_state;

	wire busy_rx;
	wire tx_start;
	assign tx_start = read | write;
	reg	write_last;

	/* Write bit conversion */
	wire       write_shift_busy;
	wire [7:0] write_shift_out;
	wire [7:0] write_fifo_out;
	wire	   write_fifo_full;
	wire       write_fifo_empty;
	wire       spi_tx_ready;

	reg        write_fifo_spi_en;

	wire[7:0]  spi_out;

	assign dout = {24'b0, spi_out};
	

	/* 32 to 8 bit conversion */
	pload_shift write_32_8(
		.clk(clk),
		.reset(reset),
		.din(din),
		.enable(tx_start),
		.dout(write_shift_out),
		.busy(write_shift_busy)
	);

	/* Write fifo */
	sync_fifo #(
		.FIFO_WIDTH(8),
		.FIFO_DEPTH(4)
	)write_fifo(
		.reset(reset),
		.clk(clk),
		.read_en(write_fifo_spi_en),
//		.read_en( (spi_tx_ready && !write_fifo_empty) && (spi_state == `SPI_WRITE_OUT )),
		.write_en(write_shift_busy),
		.din(write_shift_out),
		.dout(write_fifo_out),
		.fifo_full(write_fifo_full),
		.fifo_empty(write_fifo_empty)

	);


	/* Read bit conversion */

//	/* 8 to 32 bit conversion */
//	pread_shift read_8_32(
//		.clk(),
//		.reset(),
//		.din(),
//		.enable(busy_rx),
//		.dout(),
//		.busy(),
//		.done()
//
//	);





	/* Actual SPI controller from NANDLAND (thanks) */
	spi_master #( 
			.SPI_MODE(0), 
			.CLKS_PER_HALF_BIT(2)
	) mspi (
		.i_Rst_L(reset),
		.i_Clk(clk),
		.i_TX_Byte(write_fifo_out),
		.i_TX_DV(write_fifo_spi_en),	/* Data valid pulse for i_TX_Byte */
		.o_TX_Ready(spi_tx_ready),		/* Transmit ready for next byte */

		.o_RX_DV(busy_rx),				/* Data valid pulse (1 clock cycle) */
		.o_RX_Byte(spi_out),			/* Data to read out */

		.o_SPI_Clk(clk_out),
		.i_SPI_MISO(sdi),
		.o_SPI_MOSI(sdo)

	);


	always @(posedge clk or posedge reset) begin
		if( reset ) begin
			write_last <= 0;
			spi_state <= `SPI_IDLE;
			write_state <= `SPI_WRITE_START;
			cs <= 1;
			write_fifo_spi_en <= 0;
			busy <= 0;
		end

		case ( spi_state )
			`SPI_IDLE: begin
				
				/* Ensure no more data is read out */
				write_fifo_spi_en <= 0;
				cs <= 1'b1;
				busy <= 1'b0;

				/* Writing, should have loaded data into shift register */
				if( write && !read ) begin
					busy <= 1'b1;
					spi_state = `SPI_WRITE_FIFO;
				end
				else if( !write && read ) begin
					/* Implement reads later */
//					busy <= 1'b1;
//					spi_state = `SPI_START_READ_FIFO;
				end


			end

			`SPI_WRITE_FIFO: begin
				if( write_fifo_full ) begin
					write_fifo_spi_en <= 1;
					cs <= 1'b0;
					spi_state <= `SPI_WRITE_OUT;
				end
				else begin
					write_fifo_spi_en <= 0;
				end

			end

			`SPI_WRITE_OUT: begin
				case( write_state )
					`SPI_WRITE_START: begin
						/* Wait one more cycle in the beginning before reading
						* out data */
					   	write_fifo_spi_en <= 0;
					   	write_state <= `SPI_WAIT_READY;
					end
					`SPI_WAIT_READY: begin
						write_fifo_spi_en <= 0;
						if( spi_tx_ready  && !write_fifo_empty ) begin
							write_state <= `SPI_ENABLE_WRITE;
						end
						else if (spi_tx_ready && write_fifo_empty ) begin
							write_state <= `SPI_WRITE_LAST_BYTE;
						end
					end

					`SPI_ENABLE_WRITE: begin
						/* write has been enabled, reset pulse to wait for next
						* time it is ready */
//						if( !write_fifo_empty ) begin
						if( spi_tx_ready ) begin
					   		write_fifo_spi_en <= 1;
					   		write_state <= `SPI_WAIT_READY;
						end
//						else begin
//							write_fifo_spi_en <= 1;
//							write_state <= `SPI_WRITE_LAST_BYTE;
					//	end
					end

					`SPI_WRITE_LAST_BYTE: begin
						if( spi_tx_ready ) begin
							write_fifo_spi_en <= 1;
						end
						else begin
							write_fifo_spi_en <= 0;
					  		write_state <= `SPI_WRITE_FINISH;
						end
					end

					`SPI_WRITE_FINISH: begin
						if( spi_tx_ready ) begin
					   		write_state <= `SPI_WRITE_START;
							spi_state <= `SPI_IDLE;
						end
					end

				endcase 


				if( spi_tx_ready && write_fifo_empty ) begin

//					write_fifo_spi_en <= 0;

				end
				else if( !spi_tx_ready ) begin
					write_fifo_spi_en <= 0;
				end

			end


		endcase 

	end


endmodule
