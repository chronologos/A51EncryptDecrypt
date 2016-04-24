`timescale 1 ns / 100 ps
module Processor_Testbench();
	///////////////////////////////////////////////////////////////////////////
	parameter clock_halfperiod = 25;	// clock half period in ns

	///////////////////////////////////////////////////////////////////////////
	// Tracking the number of errors
	reg clock, ctrl_reset;	// standard signals- required even if DUT doesn't use them
	integer ticks; // ticks are HALF clock ticks... two ticks equal a clock period

	reg 			inclock, resetn;

	wire 			lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon, ps2_clock, ps2_data, a51_enterToKeyNotData, a51_startKeyStreamGen;
	wire 	[7:0] lcd_data;
	wire 	[6:0] 	sevensegout1, sevensegout2, sevensegout3;
	wire LED17, LED16, LED15, LED14, LED13;

	// instantiate the skeleton
	yt61_hw5 DUT(inclock, resetn, ps2_clock, ps2_data, a51_enterToKeyNotData, a51_startKeyStreamGen,
								/**debug_word, debug_addr**/,
								lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon, sevensegout1, sevensegout2, sevensegout3,
								LED17, LED16, LED15, LED14, LED13);



	///////////////////////////////////////////////////////////////////////////////////////////////////////
	// setting the initial values of all the reg
	initial
	begin
		inclock = 1'b0;	// at time 0
		ticks = 0;

		$display(ticks, "\n\n\n << Starting simulation (manually stop)>>\n\n");

		// $monitor("%t: addr=%h value=%h", $realtime, debug_addr, debug_word);

		#20;
	end

	// Clock generator
	always
	begin
 		#clock_halfperiod     inclock = ~inclock;    // toggle
		ticks = ticks + 1;
	end


endmodule
