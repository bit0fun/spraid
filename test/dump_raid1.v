module(dump);
	initial begin
		$dumpfile("raid1.vcd");
		$dumpvars(0, raid1);
		#1;
	end
endmodule
