module dump();
	initial begin
		$dumpfile("wb_spraid.vcd");
		$dumpvars(0, wb_spraid);
		#1;
	end
endmodule
