/* SPI RAID Controller */
`default_nettype none
`timescale 1ns/1ns

/* Define base address to be accessed at */
`define WB_ADDR_BASE		32'h30000000
`define SPRAID_MEM_SZ		32'h3FF
`define SPRAID_ADR_MAX		(`WB_ADDR_BASE + `SPRAID_MEM_SZ)
`define SPRAID_RAID_TYPE	(`WB_ADDR_BASE + 32'h400)
`define SPRAID_STATUS		(`WB_ADDR_BASE + 32'h401)

module wb_spraid (
	input			wb_clk_i,
	input  [31:0] 	wb_dat_i,
	output [31:0]	wb_dat_o,
	input			wb_rst_i,
	output			wb_ack_o,
	input  [31:0]	wb_adr_i,
	input			wb_cyc_i,
	output			wb_stall_o,
	output			wb_err_o,
	input			wb_lock_i,
	output			wb_rty_o,
	input  [3:0]	wb_sel_i,
	input			wb_stb_i,
	input			wb_we_i,

	/* SPI interface connections */

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

	reg [31:0] buf_data_o;
	wire [31:0] w_data_o;
	assign wb_dat_o = buf_data_o;

	wire read;
	wire write;
	wire enable;

	assign enable = (wb_cyc_i & wb_stb_i); 
	assign read = enable & ~wb_we_i;
	assign write = enable & wb_we_i;

	wire spraid_busy;
	wire spraid_parity;
	wire spraid_err;

	/* Busy signal dictates bus stall */
	assign wb_stall_o = spraid_busy;

	/* ACK generation */
	reg last_cycle_busy;
	reg buf_wb_ack_o;
	reg last_wb_ack_o;
	reg reg_access_ack;
	wire ack;

	assign wb_ack_o = buf_wb_ack_o;
	assign ack = last_cycle_busy & ~spraid_busy ;


	/* Register to save raid_type */
	reg [7:0] raid_type;

	/* Status registers */
	reg [7:0] status;

	wire spraid_write;
	wire spraid_read;
	assign spraid_write = write && (wb_adr_i <= `SPRAID_ADR_MAX );
	assign spraid_read = read && (wb_adr_i <= `SPRAID_ADR_MAX );

	spraid spraid(
		.reset(wb_rst_i),
		.clk(wb_clk_i),
		.raid_type( raid_type[3:0] ),
		.read( spraid_read ),
		.write( spraid_write ),
		.addr( wb_adr_i ),
		.dout( w_data_o ),
		.din( wb_dat_i ),
		.busy( spraid_busy ),
		.parity( spraid_parity ),
		.err( spraid_err ),

		.spi0_clk(spi0_clk),
		.spi0_cs(spi0_cs),
		.spi0_mosi(spi0_mosi),
		.spi0_miso(spi0_miso),

		.spi1_clk(spi1_clk),
		.spi1_cs(spi1_cs),
		.spi1_mosi(spi1_mosi),
		.spi1_miso(spi1_miso),

		.spi2_clk(spi2_clk),
		.spi2_cs(spi2_cs),
		.spi2_mosi(spi2_mosi),
		.spi2_miso(spi2_miso),

		.spi3_clk(spi3_clk),
		.spi3_cs(spi3_cs),
		.spi3_mosi(spi3_mosi),
		.spi3_miso(spi3_miso)


	);


	always @(posedge wb_clk_i or posedge wb_rst_i ) begin
		if( wb_rst_i ) begin
			last_cycle_busy <= 1;
			reg_access_ack <= 0;
			raid_type <= 1; /* RAID0 as default. should change this... */
			status <= 0;
			buf_data_o <= 0;

			buf_wb_ack_o <= 0;
			last_wb_ack_o <= 0;
			reg_access_ack <= 1'b0;

		end
		else begin

			if( reg_access_ack == 1 || (~wb_stb_i) && ~(wb_cyc_i) ) begin
				reg_access_ack <= 1'b0;
			end

			if( buf_wb_ack_o == 1 || ~(wb_stb_i) && ~(wb_cyc_i) ) begin
				buf_wb_ack_o <= 1'b0;
			end
			else begin
				buf_wb_ack_o <= ack;
			end

			/* Fill status register */
			status <= { spraid_parity, spraid_err, spraid_busy };

			/* Operations depending upon address */
			case( wb_adr_i )
				`WB_ADDR_BASE: begin
					if( read ) begin
						buf_data_o <= w_data_o;
					end

					/* Writes are handled without issue; just data in */

				end

				`SPRAID_RAID_TYPE: begin
					reg_access_ack <= 1'b1;
					if( read ) begin
						buf_data_o <= { 24'b0, raid_type};
					end
					if( write ) begin
						raid_type <= wb_dat_i[7:0];
					end

				end

				`SPRAID_STATUS: begin
					reg_access_ack <= 1'b1;
					if( read ) begin
						buf_data_o <= { 24'b0, status};
					end

					/* Can't write to status */

				end

			endcase


		end

	end




endmodule
