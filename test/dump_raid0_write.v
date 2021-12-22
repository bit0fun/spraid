module dump();
	initial begin
		$dumpfile("raid0_write.vcd");
		$dumpvars(0, raid0_write);
		#1;
	end
endmodule
