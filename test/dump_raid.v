module dump();
	initial begin
		$dumpfile("raid.vcd");
		$dumpvars(0, raid);
		#1;
	end
endmodule
