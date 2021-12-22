/* SPI Flash Controller */
`default_nettype none
`timescale 1ns/1ns
module spi_controller (
		input			reset,
		input			clk,

		input			read_in,
		input			write_in,
		
		output reg		busy,

		/* Memory access */
		input [31:0]	addr,
		input [31:0]	data,

		/* Register CMD access */
		input [3:0]		reg_sel,
		input [7:0]		reg_val,

		/* SPI interface */
		input				sdi,
		output 				sdo,
		output				clk_out,
		output				cs

);


	/* Busy flag to stall next instruction to write to SPI */
	wire busy_spi;

	/* Convert 32 bit input to FIFO 8 bit output */
	reg [31:0] data_w;
	reg [31:0] data_r;
	assign wire w_byte_0 = data_w[7:0];
	assign wire w_byte_1 = data_w[15:8];
	assign wire w_byte_2 = data_w[23:16];
	assign wire w_byte_3 = data_w[31:24];



	/* SPI Peripheral instantiation */
	spi spi0(
		.reset(reset),
		.clk_in(clk_in),
		.read(),
		.write(),
		.din(),
		.dout(),
		.busy(busy_spi),
		.sdi(sdi),
		.sdo(sdo),
		.clk_out(clk_out),
		.cs(cs)


	);


endmodule
