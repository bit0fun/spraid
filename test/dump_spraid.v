module dump();
	initial begin
		$dumpfile("spraid.vcd");
		$dumpvars(0, spraid);
		#1;
	end
endmodule
