/* SPI Peripheral */
`default_nettype none
`timescale 1ns/1ns
module flashtb (
		input		reset,
		input		clk,
		input		read,
		input		write,
		input[7:0]	din,
		output[7:0]	dout,
		output		busy

	);

	/* SPI Connections */
	wire spi_mosi;
	wire spi_miso;
	wire spi_cs;
	wire spi_clk;
	wire spi_wp;
	reg wp;

	assign spi_wp = wp;

	spi spi0(
		.reset(reset),
		.clk_in(clk),
		.read(read),
		.write(write),
		.din(din),
		.dout(dout),
		.busy(busy),

		.sdi(spi_miso),
		.sdo(spi_mosi),
		.clk_out(spi_clk),
		.cs(spi_cs)
	);

	MX25V1006F flash(
		.SCLK(spi_clk),
		.CS(spi_cs),
		.SI(spi_mosi),
		.SO(spi_miso),
		.WP(spi_wp)
	);


	initial begin
		wp <= 1'b1;

	end

endmodule
