/* SPI RAID Controller */
`default_nettype none
`timescale 1ns/1ns

/* RAID type definitions */
`define TYPE_RAID0	1
`define TYPE_RAID1	0	/* Default, since simplest */
`define TYPE_RAID5	5


module spraid(
		input			reset,
		input			clk,

		input [3:0]		raid_type,

		input			read,
		input			write,
		input [31:0]	addr,
		input [31:0]	din,
		output reg [31:0]	dout,
		output			busy,
		output reg		wbs_ack_o,	/* needed for wishbone */

		output			parity,
		output			err,



		/* SPI0 */
		output 			spi0_clk,
		output 			spi0_cs,
		output 			spi0_mosi,
		input  			spi0_miso,

		/* SPI1 */
		output 			spi1_clk,
		output 			spi1_cs,
		output 			spi1_mosi,
		input			spi1_miso,

		/* SPI2 */
		output 			spi2_clk,
		output 			spi2_cs,
		output 			spi2_mosi,
		input			spi2_miso,

		/* SPI3 */
		output 			spi3_clk,
		output 			spi3_cs,
		output 			spi3_mosi,
		input			spi3_miso

	);


	/* raid - spi wires */
	wire spi_read;
	wire spi_write;
	wire spi0_busy;
	wire spi1_busy;
	wire spi2_busy;
	wire spi3_busy;

	wire [31:0] spi_addr;

	wire [31:0] spi0_din;	
	wire [31:0] spi1_din;
	wire [31:0] spi2_din;
	wire [31:0] spi3_din;

	wire [7:0] spi0_dout;	
	wire [7:0] spi1_dout;
	wire [7:0] spi2_dout;
	wire [7:0] spi3_dout;

	wire [31:0] dout_tmp;

	reg		last_cycle_busy;
	reg		last_cycle_write;
	reg		last_cycle_read;
	wire raid_write = ( last_cycle_write && write) ? 1'b0 : write;
	wire raid_read = ( last_cycle_read && read) ? 1'b0 : read;
	wire wbs_ack;
	reg last_wbs_ack;
	assign wbs_ack = last_cycle_busy & ~busy;

	raid raid_module(
		.reset(reset),
		.clk(clk),

		/* Host control */
		.raid_type(raid_type),
		.read_en(raid_read),
		.write_en(raid_write),
		.din(din),
		.dout(dout_tmp),
		.addr(addr),
		.busy(busy),

		/* Flags */
		.parity(parity),
		.err(err),

		/* Device connections */
		.w_drives(spi_write),
		.r_drives(spi_read),

		.drive_addr(spi_addr),

		.r_drive_data0({24'b0, spi0_dout}),
		.w_drive_data0(spi0_din),
		.busy_drive0(spi0_busy),

		.r_drive_data1({24'b0,spi1_dout}),
		.w_drive_data1(spi1_din),
		.busy_drive1(spi1_busy),

		.r_drive_data2({24'b0,spi2_dout}),
		.w_drive_data2(spi2_din),
		.busy_drive2(spi2_busy),

		.r_drive_data3({24'b0,spi3_dout}),
		.w_drive_data3(spi3_din),
		.busy_drive3(spi3_busy)

	);

	/* SPI0 */
	flash_ctl drive0(
		.reset(reset),
		.clk(clk),
		.read(spi_read),
		.write(spi_write),
		.addr(spi_addr[15:0]),
		.din(spi0_din[7:0]),
		.dout(spi0_dout),
		.busy(spi0_busy),
		
		/* SPI */
		.spi_clk(spi0_clk),
		.spi_cs(spi0_cs),
		.spi_mosi(spi0_mosi),
		.spi_miso(spi0_miso)

	);

	/* SPI1 */
	flash_ctl drive1(
		.reset(reset),
		.clk(clk),
		.read(spi_read),
		.write(spi_write),
		.addr(spi_addr[15:0]),
		.din(spi1_din[7:0]),
		.dout(spi1_dout),
		.busy(spi1_busy),
		
		/* SPI */
		.spi_clk(spi1_clk),
		.spi_cs(spi1_cs),
		.spi_mosi(spi1_mosi),
		.spi_miso(spi1_miso)

	);

	/* SPI2 */
	flash_ctl drive2(
		.reset(reset),
		.clk(clk),
		.read(spi_read),
		.write(spi_write),
		.addr(spi_addr[15:0]),
		.din(spi2_din[7:0]),
		.dout(spi2_dout),
		.busy(spi2_busy),
		
		/* SPI */
		.spi_clk(spi2_clk),
		.spi_cs(spi2_cs),
		.spi_mosi(spi2_mosi),
		.spi_miso(spi2_miso)

	);

	/* SPI3 */
	flash_ctl drive3(
		.reset(reset),
		.clk(clk),
		.read(spi_read),
		.write(spi_write),
		.addr(spi_addr[15:0]),
		.din(spi3_din[7:0]),
		.dout(spi3_dout),
		.busy(spi3_busy),

		/* SPI */
		.spi_clk(spi3_clk),
		.spi_cs(spi3_cs),
		.spi_mosi(spi3_mosi),
		.spi_miso(spi3_miso)

	);

	always @(posedge clk or posedge reset ) begin
		if( reset ) begin
			wbs_ack_o <= 0;
			last_wbs_ack <= 0;
			dout <= 0;
			last_cycle_busy <= 1;
			last_cycle_read <= 0;
			last_cycle_write <= 0;
		end
		else begin
			last_wbs_ack <= wbs_ack;
			if( last_wbs_ack && !wbs_ack ) begin
				wbs_ack_o <= 1'b1;
			end
			else if ( last_wbs_ack && wbs_ack ) begin
				wbs_ack_o <= 1'b1;
			end
			else if( !last_wbs_ack && wbs_ack ) begin
				wbs_ack_o <= 1'b1;
			end
			else begin
				wbs_ack_o <= 1'b0;
			end
			dout <= dout_tmp;
			last_cycle_busy <= busy;
			last_cycle_read <= read;
			last_cycle_write <= write;
		end
	end

endmodule
