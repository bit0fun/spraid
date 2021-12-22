module(dump);
	initial begin
		$dumpfile("raid5.vcd");
		$dumpvars(0, raid5);
		#1;
	end
endmodule
