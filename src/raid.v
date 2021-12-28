/* RAID Control */
`default_nettype none
`timescale 1ns/1ns

/* RAID type definitions */
`define TYPE_RAID0	1
`define TYPE_RAID1	0	/* Default, since simplest */
`define TYPE_RAID5	5

/* Assume 32 bit address, 32 bit data for now. Will parameterize later.
* Output data will also be 32 bits to make things simpler on this side */

module raid #(
		parameter NDRIVES = 4
	)
	(
		input				reset,
		input				clk,
		input				read_en,
		input				write_en,

		/* Host connection  */
		input      [31:0]	din,
		input      [31:0]	addr,
		output reg [31:0]	dout,
		output reg			busy,
		output reg			parity,		/* parity error that is non recoverable */
		output reg			err,		/* error flag on raid0 consistency */
		input [3:0]			raid_type,

		/* Drive controller connection */
		output reg			w_drives,
		output reg			r_drives,
		output reg [31:0]	drive_addr,
		input				busy_drive0,
		input				busy_drive1,
		input				busy_drive2,
		input				busy_drive3,

		input      [31:0]	r_drive_data0,
		input      [31:0]	r_drive_data1,
		input      [31:0]	r_drive_data2,
		input      [31:0]	r_drive_data3,

		output reg [31:0]	w_drive_data0,
		output reg [31:0]	w_drive_data1,
		output reg [31:0]	w_drive_data2,
		output reg [31:0]	w_drive_data3

	);

	/* Statemachine for operation */
	`define OP_NOP	 		0
	`define OP_READ	 		1
	`define OP_WRITE	 	2
	`define OP_WRITE_FINISH 3 /* Waiting for write to finish */
	`define OP_READ_WAIT	4
	reg [3:0] op;
	reg [3:0] last_op;

	/* Temporary storage */
	//reg [31:0] tmp_addr;
	reg [31:0] tmp_data;


	/* Busy connection tying all drives together */
	wire drive_busy;
	assign drive_busy = busy_drive0 | busy_drive1 | busy_drive2 | busy_drive3;


	/* RAID 0 wires */
	
	/* Write */
	wire [7:0] w_raid0_d0;
	wire [7:0] w_raid0_d1;
	wire [7:0] w_raid0_d2;
	wire [7:0] w_raid0_d3;

	assign w_raid0_d0 = tmp_data[7:0];
	assign w_raid0_d1 = tmp_data[15:8];
	assign w_raid0_d2 = tmp_data[23:16];
	assign w_raid0_d3 = tmp_data[31:24];

	/* Read */
	wire [31:0] r_raid0;
	assign r_raid0 = { r_drive_data3[7:0], r_drive_data2[7:0], r_drive_data1[7:0], r_drive_data0[7:0]};

	/* RAID 1 wires */

	/* Equivalence check needed for read */
	wire eq_d0d1; 
    wire eq_d1d2;
    wire eq_d2d3; 
    wire r_raid1_eq;
	assign eq_d0d1 = (r_drive_data0 == r_drive_data1);
	assign eq_d1d2 = (r_drive_data1 == r_drive_data2);
	assign eq_d2d3 = (r_drive_data2 == r_drive_data3);
	assign r_raid1_eq = (eq_d0d1 && eq_d1d2 && eq_d2d3);
	
	/* Write */
	wire [31:0] w_raid1_d0;
    wire [31:0] w_raid1_d1;
    wire [31:0] w_raid1_d2;
    wire [31:0] w_raid1_d3;

	assign w_raid1_d0 = tmp_data;
	assign w_raid1_d1 = tmp_data;
	assign w_raid1_d2 = tmp_data;
	assign w_raid1_d3 = tmp_data;

	/* Read */

	/* Only use drive 0 if all equivalent, need to figure out other handling to
	* make this better. As in use the most common data output, instead of only
	* relying on them all being consistent */
	wire [31:0] r_raid1;
	assign r_raid1 = ( r_raid1_eq ) ? r_drive_data0 : 32'b0;

	/* RAID 5 wires */

	/* Read */

	/* Only 24 bits because byte 3 is parity */
	wire [31:0] r_raid5;
	assign r_raid5 = { {8'b0}, r_drive_data2[7:0], r_drive_data1[7:0], r_drive_data0[7:0]};

	/* parity check */
	wire [7:0] r_raid5_parity_d0d1;
    wire [7:0] r_raid5_parity_d2d3;
	assign r_raid5_parity_d0d1 = r_drive_data0[7:0] ^ r_drive_data1[7:0];
	assign r_raid5_parity_d2d3 = r_drive_data2[7:0] ^ r_drive_data3[7:0];

	/* If no issues, then should be zero ( xor with itself is zero )*/
	wire r_raid5_parity_err;
	assign r_raid5_parity_err = r_raid5_parity_d0d1 ^ r_raid5_parity_d2d3;


	/* Write */
	/* Parity calculations */
	wire [7:0] w_raid5_parity_d0d1;
    wire [7:0] w_raid5_parity;
	assign w_raid5_parity_d0d1 = tmp_data[7:0] ^ tmp_data[15:8];
	assign w_raid5_parity      = w_raid5_parity_d0d1 ^ tmp_data[23:16];

	wire [7:0] w_raid5_d0;
    wire [7:0] w_raid5_d1;
    wire [7:0] w_raid5_d2;
    wire [7:0] w_raid5_d3;
	assign w_raid5_d0 = tmp_data[7:0];
	assign w_raid5_d1 = tmp_data[15:8];
	assign w_raid5_d2 = tmp_data[23:16];
	assign w_raid5_d3 = w_raid5_parity;

	reg [31:0] dout_tmp;

	always @( posedge clk or posedge reset ) begin
		if( reset ) begin
			dout <= 0;
			busy <= 1;
			parity <= 0;
			err <= 0;

			w_drives <= 0;
			r_drives <= 0;

			w_drive_data0 <= 0;
			w_drive_data1 <= 0;
			w_drive_data2 <= 0;
			w_drive_data3 <= 0;

			op <= `OP_NOP;
			tmp_data <= 0;

			drive_addr <= 0;
			last_op <= `OP_NOP;

			dout_tmp <= 0;

		end
		else begin

			/* Store previous OP */
			last_op <= op;
		
			/* Busy when drives are, but don't set busy otherwise. */
			if( (busy == 0) && (drive_busy) ) begin
				busy <= 1'b1;
			end
			else if( (busy == 1) && (!drive_busy) && (last_op == `OP_NOP ) )begin
				busy <= 1'b0;
			end
			w_drives <= 1'b0;
			r_drives <= 1'b0;

			dout <= dout_tmp;

			case ( op )
				`OP_NOP: begin
					/* Determine operation */
					if( write_en && !read_en ) begin
						/* Writing */
						op <= `OP_WRITE;
						drive_addr <= addr;
						/* Output write signal, next cycle */
						w_drives <= 1'b0;
						r_drives <= 1'b0;

						/* save input data */
						tmp_data <= din;
						
					end
					else if( !write_en && read_en ) begin
						/* Reading */
						op <= `OP_READ_WAIT;
						drive_addr <= addr;
						/* Output read signal next cycle */
						w_drives <= 1'b0;
						r_drives <= 1'b0;

						/* Make sure input register is clear */
						tmp_data <= 0;
						
					end
				end
				
				`OP_WRITE: begin
					w_drives <= 1'b1;
					r_drives <= 1'b0;
					case ( raid_type )
						`TYPE_RAID0: begin
							/* Data striping. Only use 8 bits, since it is simpler */
							w_drive_data0 <= w_raid0_d0;
							w_drive_data1 <= w_raid0_d1;
							w_drive_data2 <= w_raid0_d2;
							w_drive_data3 <= w_raid0_d3;
							op <= `OP_WRITE_FINISH;
		
						end
		
						`TYPE_RAID1: begin
							/* Copy to all outputs */
							w_drive_data0 <= w_raid1_d0;
							w_drive_data1 <= w_raid1_d1;
							w_drive_data2 <= w_raid1_d2;
							w_drive_data3 <= w_raid1_d3;
							op <= `OP_WRITE_FINISH;
		
						end
		
						`TYPE_RAID5: begin
							/* Write 24 bits, with parity */
							w_drive_data0 <= w_raid5_d0;
							w_drive_data1 <= w_raid5_d1;
							w_drive_data2 <= w_raid5_d2;
							w_drive_data3 <= w_raid5_d3;
							op <= `OP_WRITE_FINISH;
						end
		
					endcase 
				end

				`OP_READ_WAIT: begin
					if( drive_busy ) begin
						w_drives <= 1'b0;
						r_drives <= 1'b0;
						op <= `OP_READ;
					end
					else begin
						w_drives <= 1'b0;
						r_drives <= 1'b1;
					end
				end

				`OP_READ: begin
					case ( raid_type )
						`TYPE_RAID0: begin
							/* Read */
							if( !drive_busy ) begin
								dout_tmp <= r_raid0;
//								w_drives <= 1'b0;
//								r_drives <= 1'b0;
								op <= `OP_NOP;
								tmp_data <= 0;
							end
							/* Still busy, keep reading */
							else begin
								tmp_data <= r_raid0;
							end
						end
		
						`TYPE_RAID1: begin
							/* Copied data */
							/* Check if data is ready, and no issues */
							if( !drive_busy && r_raid1_eq ) begin
								dout_tmp <= r_raid1;//tmp_data;
								op <= `OP_NOP;
//								w_drives <= 1'b0;
//								r_drives <= 1'b0;
								tmp_data <= 0;
							end

							/* Data integrity is broken, raise error, no data
							* out */
							else if( !drive_busy && !r_raid1_eq ) begin
								err <= 1'b1;
								dout_tmp <= 32'hFFFFFFFF;
								op <= `OP_NOP;
//								w_drives <= 1'b0;
//								r_drives <= 1'b0;
								tmp_data <= 0;
							end
							else if( drive_busy ) begin
								/* Keep reading in data, should be ready once
								* busy is over */
							   	
							   	tmp_data <= r_raid1;
							end
		
						end
		
						`TYPE_RAID5: begin
							if( !drive_busy ) begin
								/* Output parity status  */
								parity <= r_raid5_parity_err;
								op <= `OP_NOP;
//								w_drives <= 1'b0;
//								r_drives <= 1'b0;
								dout_tmp <= r_raid5;
								tmp_data <= 0;
							end
							else begin
								/* Keep reading in data, should be complete
								* once busy is over */
							    tmp_data <= r_raid5;

							end
						end
		
					endcase 


				end
				`OP_WRITE_FINISH: begin
					w_drives <= 1'b0;
					r_drives <= 1'b0;
					/* Need to wait for busy signals to clear before continuing */
					if( !drive_busy ) begin
						op <= `OP_NOP;
						/* Clean up signals */
//						w_drives <= 1'b0;
//						r_drives <= 1'b0;
						tmp_data <= 0;
//						busy <= 1'b0;

						w_drive_data0 <= 0;
						w_drive_data1 <= 0;
						w_drive_data2 <= 0;
						w_drive_data3 <= 0;
					end


				end

				default: begin
						op <= `OP_NOP;
				end



			endcase 


		end

	end
	

	/* Formal verification */
	`ifdef FORMAL
		reg past_available = 0;
			initial begin
				assume(reset);
			end
			always @(posedge clk) begin
			assume( addr != 0 );

			assume( din != 0 );
			assume( din[7:0] != 0 );
			assume( din[15:8] != 0 );
			assume( din[23:16] != 0 );

			assume( (raid_type == `TYPE_RAID0) || (raid_type == `TYPE_RAID1) || (raid_type == `TYPE_RAID5) );

			/* Setup $past */
			past_available <= 1'b1;

			if( past_available && $past(reset) && !reset ) begin
				assume( addr == $past(addr) );

				case ( op )
					`OP_NOP: begin
						/* Should not have anything asserted right now */
						nop_wsig: assert(w_drives == 0);
						nop_rsig: assert(r_drives == 0);
						nop_prevop: assert( ($past(op) == `OP_READ) || ($past(op) == `OP_WRITE_FINISH) || $past(op) == `OP_NOP);
						cover_nop_read: cover( ($past(op) == `OP_READ) ) ;
						cover_nop_write: cover( ($past(op) == `OP_WRITE_FINISH) ) ;
					end

					`OP_READ: begin
						read_prevsig: assert( ($past(write_en) == 0) && ($past(read_en) == 1) );
						read_wsig: assert(w_drives == 0);
						read_rsig: assert(r_drives == 1);
						read_prevop: assert( $past(op) == `OP_NOP );
						cover_read_nop: cover( $past(op) == `OP_NOP );

					end

					`OP_WRITE: begin
						write_prevsig: assert( ($past(write_en) == 1) && ($past(read_en) == 0) );
						write_wsig: assert(w_drives == 1);
						write_rsig: assert(r_drives == 0);
						write_prevop: assert( $past(op) == `OP_NOP );
						cover_write_prevop: cover( $past(op) == `OP_NOP );
					end

					`OP_WRITE_FINISH: begin
						write_finish_wsig: assert(w_drives == 0);
						write_finish_rsig: assert(r_drives == 0);
						write_finish_prevop: assert( $past(op) == `OP_WRITE );
						cover_write_finish_prevop: cover( $past(op) == `OP_WRITE );

					end


				endcase 


			end
		end

	`endif


endmodule






