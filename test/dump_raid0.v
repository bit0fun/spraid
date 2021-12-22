module(dump);
	initial begin
		$dumpfile("raid0.vcd");
		$dumpvars(0, raid0);
		#1;
	end
endmodule
