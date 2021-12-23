module dump();
	initial begin
		$dumpfile("flashtb.vcd");
		$dumpvars(0, flashtb);
		#1;
	end
endmodule
