module dump();
	initial begin
		$dumpfile("pread_shift.vcd");
		$dumpvars(0, pread_shift);
		#1;
	end
endmodule
