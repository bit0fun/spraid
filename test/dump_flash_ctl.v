module(dump);
	initial begin
		$dumpfile("flash_ctl.vcd");
		$dumpvars(0, flash_ctl);
		#1;
	end
endmodule
