module dump();
	initial begin
		$dumpfile("spi.vcd");
		$dumpvars(0, spi);
		#1;
	end
endmodule
