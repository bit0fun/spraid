/* FPGA FLash control test  */
`default_nettype none
`timescale 1ns/1ns


/* Static values for testing */
`define TEST_ADDR	16'h01AA
`define TEST_DATA	8'h55

module flash_test (
		input	reset,
		input	clk,
	
		output	busy,
	
(*keep*)	input	BTN1,	/* test write */
(*keep*)	input	BTN2,	/* test read */

		output reg LED1,
		output reg LED2,
		output reg LED3,
	
		/* spi */
(*keep*)		output spi_clk,
(*keep*)		output spi_cs,
(*keep*)		output spi_mosi,
(*keep*)		input  spi_miso


	);

//	reg [7:0] clk_div;
//	wire clk_div8;
//	assign clk_div8 = clk_div[7];
	
	wire nreset;
	assign nreset = ~reset;
	
	reg[15:0] test_addr;
	reg[7:0]  data;

	/* rw signals */
	reg read;
	reg write;

	/* button handling */
//	wire start_test_write;
//	wire start_test_read;
	reg start_test_write;
	reg start_test_read;

//	assign start_test_write = BTN2;
//	assign start_test_read = BTN1;

	/* test state */
	`define TEST_IDLE  	0
	`define TEST_WAIT 	1
	`define TEST_FINISH 2
	reg [2:0] test_state;

	reg [7:0] counter;

	wire [7:0] dout;
	
	flash_ctl flash(
		.reset(nreset),
		.clk(clk),
		.read(read),
		.write(write),
		.addr(test_addr),
		.din(data),
		.dout(dout),
		.busy(busy),
		
		/* spi */
		.spi_clk(spi_clk),
		.spi_cs(spi_cs),
		.spi_mosi(spi_mosi),
		.spi_miso(spi_miso)
	
	
	);


	always  @(posedge clk or posedge nreset) begin
		if( nreset ) begin
			test_addr <= `TEST_ADDR;
			data <= `TEST_DATA;
			read <= 0;
			write <= 0;
			test_state <= 0;
			LED1 <= 0;
			LED2 <= 0;
			LED3 <= 0;
			counter <= 8'hFF;
//			clk_div <= 8'hFF;
			start_test_write <= 1'b0;
			start_test_read <= 1'b0;
		end
		else begin
//			if(clk_div == 0) begin
//				clk_div <= 8'hFF;
//			end
//			else begin
//				clk_div <= clk_div -1;
//			end
			case (test_state)
				`TEST_IDLE: begin
					LED1 <= 1;
					LED2 <= 0;
					LED3 <= 0;
					start_test_read <= BTN2;
					start_test_write <= BTN1;
					if(!busy) begin 

						if( !start_test_read && start_test_write ) begin
							/* test write */
							test_state <= `TEST_WAIT;
							read <= 1'b0;
							write <= 1'b1;
						end
						else if (start_test_read && !start_test_write) begin
							/* test read */
							test_state <= `TEST_WAIT;
							read <= 1'b1;
							write <= 1'b0;
						end
						else begin
							read <= 1'b0;
							write <= 1'b0;					
						end
					end
				end

				`TEST_WAIT: begin
					LED1 <= 0;
					LED2 <= 1;
					LED3 <= 0;
					read <= 1'b0;
					write <= 1'b0;					
					counter <= 8'hFF;
					if( !busy ) begin
						test_state <= `TEST_FINISH;
					end

				end

				`TEST_FINISH: begin
					LED1 <= 0;
					LED2 <= 0;
					LED3 <= 1;
					if( counter == 0 ) begin
						test_state <= `TEST_IDLE;		
					end
					else begin
						counter <= counter - 1;
					end

				end


			endcase

		end


	end


endmodule
