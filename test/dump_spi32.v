module dump();
	initial begin
		$dumpfile("spi32.vcd");
		$dumpvars(0, spi32);
		#1;
	end
endmodule
