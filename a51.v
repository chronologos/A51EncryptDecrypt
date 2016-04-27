/***
	_______  _______         __
	(  ___  )(  ____ \     /\/  \
	| (   ) || (    \/    / /\/) )
	| (___) || (____     / /   | |
	|  ___  |(_____ \   / /    | |
	| (   ) |      ) ) / /     | |
	| )   ( |/\____) )/ /    __) (_
	|/     \|\______/ \/     \____/

	Spring 2016, Yi Yan Tay and Anthony Yu
	Hardware implementation of the ubiquitous A5/1 cipher used in GSM communications.

	instantiation
	a51 myA51(.clk(), .reset(), .enable(), .enterToKeyNotData(), .startKeyStreamGen(), .ps2_key_pressed(), .ps2_key_data(), .LEDerror(), .LEDenterToKeyNotData(), .LEDstartKeyStreamGen(), .LEDKeyStreamDepleted(), .LEDmessage_to_lcd_done(), .keyindex_out(), .dataindex_out(), .data_to_lcd_out(), .lcd_reset(), .lcd_enable());
***/

module a51(clk, reset, enable, enterToKeyNotData, startKeyStreamGen, ps2_key_pressed, ps2_key_data, LEDerror, LEDenterToKeyNotData, LEDstartKeyStreamGen, LEDKeyStreamDepleted, LEDmessage_to_lcd_done, keyindex_out, dataindex_out, data_to_lcd_out, lcd_reset, lcd_enable, keystream_to_processor);

	input clk, reset, enable; //ASSIGN reset to some button.
	input enterToKeyNotData; // Another flip switch
	input startKeyStreamGen; // Flip Switch
	input ps2_key_pressed;
	input [7:0] ps2_key_data;

	output LEDerror, LEDenterToKeyNotData, LEDstartKeyStreamGen, LEDKeyStreamDepleted, LEDmessage_to_lcd_done;// LED
	output[3:0] keyindex_out;
	output[4:0] dataindex_out;
	output[7:0] data_to_lcd_out;
	output lcd_reset; // a51 unit needs to be able to reset LCD module.
	output lcd_enable;
	output [127:0] keystream_to_processor;

	wire error;
	wire[7:0] data_to_lcd;
	wire[3:0] final_xor_output;
	wire KeyStreamDepleted, KeyStreamReady, a51out;
	wire internal_lcd_reset, internal_lcd_enable;

	//Converters to look up scan codes.
	wire[7:0] asciiout,ascii_xored;
	wire[3:0] hexout;
	scantoascii Converter(ps2_key_data,asciiout); //goes to LCD from input
	scantohex Converter2(ps2_key_data,hexout); // goes to keyreg and datareg
	hextoascii Converter3(final_xor_output, ascii_xored); // goes to LCD from output
	wire backspace_detected = &(asciiout ^~8'h3C);
	wire break_code_detected = &(asciiout ^~ 8'h21);
	assign error = &(asciiout^~ 8'h78);

	wire accept_ps2_input;
	//JKFFE to only detect keypress after breakcode  We only want to use value of ps2_key_data every three
	// key presses because a single press of a key sends both a 4 bit make and a 16 bit break code.
	JKFFE breakCode(.J(break_code_detected & ps2_key_pressed), .K(~break_code_detected & ps2_key_pressed), .CLK(clk), .CLRN(~reset), .PRN(1'b1), .ENA(enable), .Q(accept_ps2_input));


	/***
	Do edge detection: We want to detect the clock cycle that startKeyStreamGen just turns on. We use two DFFEs.
	Compare output of last in the series with first in the series. If XOR ^ returns 1 we know there is an edge. If XNOR ~^
	returns 1 we know there is no edge. Bounty!
	***/
	wire startKeyStreamGenDFF1_out, startKeyStreamGenDFF2_out;
	wire startKeyStreamGenEdge = startKeyStreamGenDFF1_out ^ startKeyStreamGenDFF2_out; //used to send to keyframeLFSR
	DFFE startKeyStreamGenDFF1(.d(startKeyStreamGen),.clrn(~reset),.prn(1'b1),.clk(clk),.q(startKeyStreamGenDFF1_out),.ena(1'b1));
	DFFE startKeyStreamGenDFF2(.d(startKeyStreamGenDFF1_out),.clrn(~reset),.prn(1'b1),.clk(clk),.q(startKeyStreamGenDFF2_out),.ena(1'b1));

	// more edge detection
	wire KeyStreamDepletedEdge, KeyStreamDepletedDFF1_out,  KeyStreamDepletedDFF2_out, KeyStreamDepletedDFF3_out;
	assign KeyStreamDepletedEdge = KeyStreamDepletedDFF1_out ^ KeyStreamDepletedDFF2_out; //used to send to keyframeLFSR
	DFFE KeyStreamDepletedDFF1(.d(KeyStreamDepleted),.clrn(~reset),.prn(1'b1),.clk(clk),.q(KeyStreamDepletedDFF1_out),.ena(1'b1));
	DFFE KeyStreamDepletedDFF2(.d(KeyStreamDepletedDFF1_out),.clrn(~reset),.prn(1'b1),.clk(clk),.q(KeyStreamDepletedDFF2_out),.ena(1'b1));
	DFFE KeyStreamDepletedDFF3(.d(KeyStreamDepletedDFF2_out),.clrn(~reset),.prn(1'b1),.clk(clk),.q(KeyStreamDepletedDFF3_out),.ena(1'b1));


	/**
		__     ___  ____
	 (  )   / __)(    \
	 / (_/\( (__  ) D (
	 \____/ \___)(____/

	 LCD is in external module but has controls we need to assert within this one.

	 We need to @internal_lcd_reset LCD at a few points. 1) When hard reset is asserted. 2) When we flip switch to start entering data. 3) When we flip switch to start keystreamgen.

	 We @internal_lcd_enable this for display of input key and data, which is when @startKeyStreamGen is 0. We also enable this when we want to output ciphertext, which is when KeyStreamDepleted & startKeyStreamGenDFF2_out.
	**/

	wire enterToKeyNotDataEdge, message_to_lcd_done;
	assign internal_lcd_enable = (ps2_key_pressed & accept_ps2_input & ~startKeyStreamGenDFF2_out) | (startKeyStreamGenDFF2_out & KeyStreamDepletedDFF3_out & ~message_to_lcd_done);
	assign internal_lcd_reset = (reset | enterToKeyNotDataEdge | startKeyStreamGenEdge );

	my_tri #(8) data_to_lcd_tri1(asciiout, ~startKeyStreamGen, data_to_lcd);
	my_tri #(8) data_to_lcd_tri2(ascii_xored, startKeyStreamGen, data_to_lcd);

	/*** Data and Key counters for storing into datastore_reg and keyframe_reg ***/
	wire [3:0] keyindex;
	wire [4:0] dataindex;
	key_counter mykeycounter (.clock(clk), .reset(reset), .index(keyindex), .enterToKey(enterToKeyNotData & ~startKeyStreamGen), .keyPress(ps2_key_pressed & accept_ps2_input), .backspace(backspace_detected));
	data_counter mydatacounter (.clock(clk), .reset(reset), .index(dataindex), .enterToData(~enterToKeyNotData & ~startKeyStreamGen), .keyPress(ps2_key_pressed & accept_ps2_input), .backspace(backspace_detected));


	// Edge detection for when we switch from entering data to entering key
	wire enterToKeyNotDataDFF1_out, enterToKeyNotDataDFF2_out;
	assign enterToKeyNotDataEdge = enterToKeyNotDataDFF1_out ^ enterToKeyNotDataDFF2_out;
	DFFE enterToKeyNotDataDFF1(.d(enterToKeyNotData),.clrn(~reset),.prn(1'b1),.clk(clk),.q(enterToKeyNotDataDFF1_out),.ena(1'b1));
	DFFE enterToKeyNotDataDFF2(.d(enterToKeyNotDataDFF1_out),.clrn(~reset),.prn(1'b1),.clk(clk),.q(enterToKeyNotDataDFF2_out),.ena(1'b1));

	/***
	Instantiate special register stores for key+frame (86 bits) and message (128 bits). These registers are special as
	They allow the writing of 8 bits at a time into different indices. They are controlled by a counter which increments
	Its count every time there is a new keypress. key + frame eventually piped into a LFSR, where it is then piped into a51 unit
	***/
	wire [85:0] keyframe_out;
	wire [127:0] datastore_out;
	keyframe_reg key(.ps2data_in(hexout), .keyindex(keyindex), .keyframe_out(keyframe_out), .write_enable(enterToKeyNotData & ps2_key_pressed & ~startKeyStreamGen & accept_ps2_input), .clk(clk), .reset(reset));
	datastore_reg data(.ps2data_in(hexout), .index(dataindex), .datastore_out(datastore_out), .write_enable(~enterToKeyNotData & ps2_key_pressed & ~startKeyStreamGen & accept_ps2_input), .clk(clk), .reset(reset));

	// instantiate keyframeLFSR, this will take input from our keyframe_reg
	wire[85:0] keyframeLFSR_out, keyframeLFSR_prn, keyframeLFSR_clrn;
	my_tri #(86) keyframeLFSRprntri(.in({keyframe_out,22'h000134}),.enable(startKeyStreamGenEdge),.out(keyframeLFSR_prn));
	my_tri #(86) keyframeLFSRprntri2(.in({86{1'b0}}),.enable(~startKeyStreamGenEdge),.out(keyframeLFSR_prn));
	my_tri #(86) keyframeLFSRclrntri(.in({keyframe_out,22'h000134}),.enable(startKeyStreamGenEdge),.out(keyframeLFSR_clrn));
	my_tri #(86) keyframeLFSRclrntri2(.in({86{1'b1}}),.enable(~startKeyStreamGenEdge),.out(keyframeLFSR_clrn));
	wire keyframeLFSR_in;
	assign keyframeLFSR_in = 1'bz;
	LFSR #(86) keyframeLFSR(clk,keyframeLFSR_in,keyframeLFSR_out,1'b1,keyframeLFSR_clrn,~keyframeLFSR_prn);

	//instantiate a51
	wire [18:0] r19out; // outputs of each LFSR in A5/1
	wire [21:0] r22out;	// outputs of each LFSR in A5/1
	wire [22:0] r23out;	// outputs of each LFSR in A5/1

	/***
	A51 Cipher Unit
	Some counterintuitive pin assignments here.
	we reset on @startKeyStreamGenEdge.

	1 -> DFF1 ->1  DFF2 -> 0
	this is clock cycle with @startKeyStreamGenEdge, we reset the counter here.

	1 -> DFF1 ->1  DFF2 -> 1
	this is clock cycle when startKeyStreamGenDFF2_out = 1 and this is when counter is enabled.

	startKeyStreamGen is assigned to startKeyStreamGenDFF2_out

	our input should be keyframeLFSR_out[85], remember how LFSR works...
	EXAMPLE 6 bit LFSR: [input ⇒ 0 ⇒ 1 ⇒ 2 ⇒ 3 ⇒ 4 ⇒ 5 ⇒ output]

	***/

	a51_keygen mya51(clk,reset|startKeyStreamGenEdge, keyframeLFSR_out[85], startKeyStreamGenDFF2_out, KeyStreamReady, KeyStreamDepleted, a51out, r19out, r22out, r23out);

	wire[127:0] a51_bitstream_aggregated, xored_out;
	//	module LFSR(clk,in,out,write_enable,clrn,prn);
	// assign a51_bitstream_aggregated = {128{1'b1}}; //DEBUG
	LFSR #(128) a51_bitstream(clk,a51out,a51_bitstream_aggregated,KeyStreamReady&~KeyStreamDepletedDFF2_out,{128{~reset}},{128{1'b1}});
	yt61_reg #(128) xoredoutput(.reg_d(a51_bitstream_aggregated ^ datastore_out), .reg_prn({128{1'b1}}) , .reg_clrn({128{~reset}}), .reg_f(xored_out), .write_enable(KeyStreamDepletedDFF2_out), .clk(clk));

	// we need to be able to read out 128 bit xord output 4 bits at a time using an up counter.
	wire [7:0] up_counter_out;
	assign message_to_lcd_done = &(up_counter_out[5:0] ~^ 6'd32);
	up_counter myGiantMuxUpCounter(.out(up_counter_out), .enable(KeyStreamDepletedDFF3_out & ~message_to_lcd_done), .clk(clk), .reset(reset));
	giantMux myGiantMux(.in(xored_out),.index(up_counter_out[4:0]),.out(final_xor_output));
	// print QWER
	// giantMux myGiantMux(.in(xored_out),.index(up_counter_out[4:0]),.out(final_xor_output));

	/***
		__   _  _  ____  ____  _  _  ____  ____
	 /  \ / )( \(_  _)(  _ \/ )( \(_  _)/ ___)
	(  O )) \/ (  )(   ) __/) \/ (  )(  \___ \
	 \__/ \____/ (__) (__)  \____/ (__) (____/
	***/

	assign LEDerror = error;
	assign LEDenterToKeyNotData = enterToKeyNotDataDFF2_out;
	assign LEDstartKeyStreamGen = startKeyStreamGenDFF2_out;
	assign LEDKeyStreamDepleted = KeyStreamDepleted;
	assign LEDmessage_to_lcd_done = message_to_lcd_done;
	assign keyindex_out = keyindex;
	assign dataindex_out = dataindex;
	assign data_to_lcd_out = data_to_lcd;
	assign lcd_reset = internal_lcd_reset;
	assign lcd_enable = internal_lcd_enable;
	assign keystream_to_processor = a51_bitstream_aggregated;

endmodule

/***
Keystream Generator. Generates 224 bits of valid keystream output for use in stream cipher.
Unit starts operating when @startKeyStreamGen is asserted. Last four parameters are testing.
***/
module a51_keygen(clk, reset, loadin, startKeyStreamGen, KeyStreamReady, KeyStreamDepleted, a51out, r19out, r22out, r23out); // T
	input reset, clk;
	input startKeyStreamGen; // pin assignment to flip switch
	input loadin; // stream from keyframLFSR
	output KeyStreamReady, KeyStreamDepleted; // assigned to outputstage and done respectively
	output a51out; // final output bit by bit of the A5/1
	output[18:0] r19out; // outputs of each LFSR in A5/1
	output [21:0] r22out;	// outputs of each LFSR in A5/1
	output [22:0] r23out;	// outputs of each LFSR in A5/1

	/*** instantiate counter, this will be the "pulse" of the A5/1 cipher encrypt/decrypt unit.
	we know that the A5/1 cipher setup has 4 stages: 64 cycle key xor, 22 cycle frame xor
	100 cycle irregular clocking and 128 cycles of valid output. these lines will be asserted
	whenever the respective stage is true
	***/
	wire stageone,stagetwo,stagethree,outputstage,done;
	assign KeyStreamReady = outputstage;
	assign KeyStreamDepleted = done;
	wire [9:0] counter_out;
	a51counter myCounter(.C(clk), .CLR(reset), .Q(counter_out), .ENABLE(startKeyStreamGen) , .STAGEONE(stageone), .STAGETWO(stagetwo), .STAGETHREE(stagethree),.OUTPUTSTAGE(outputstage),.DONE(done));

	//majority clocking
	wire[18:0] LFSR19_out;
	wire[21:0] LFSR22_out;
	wire[22:0] LFSR23_out;
	wire clock_majority_bit;
	majority3 m3(LFSR19_out[8], LFSR22_out[10], LFSR23_out[10], clock_majority_bit);
	wire clock19 = clock_majority_bit ~^ LFSR19_out[8];
	wire clock22 = clock_majority_bit ~^ LFSR22_out[10];
	wire clock23 = clock_majority_bit ~^ LFSR23_out[10];

	// instantiate LFSRs, the enable field of each lfsr holds the combinational logic that decides whether or not to clock that lsfr for that particular cycle.
	wire LFSR19_in;
	LFSR #(19) LFSR19(clk,LFSR19_in,LFSR19_out,((clock19&(stagethree|outputstage))|(stageone|stagetwo)),{19{~reset}},{19{1'b1}});
	wire LFSR22_in;
	LFSR #(22) LFSR22(clk,LFSR22_in,LFSR22_out,((clock22&(stagethree|outputstage))|(stageone|stagetwo)),{22{~reset}},{22{1'b1}});
	wire LFSR23_in;
	LFSR #(23) LFSR23(clk,LFSR23_in,LFSR23_out,((clock23&(stagethree|outputstage))|(stageone|stagetwo)),{23{~reset}},{23{1'b1}});

	assign r19out = LFSR19_out;
	assign r22out = LFSR22_out;
	assign r23out = LFSR23_out;

	// xors
	wire LFSR19xor_out = LFSR19_out[18] ^ LFSR19_out[17] ^ LFSR19_out[16] ^ LFSR19_out[13];
	wire LFSR22xor_out = LFSR22_out[21] ^ LFSR22_out[20];
	wire LFSR23xor_out = LFSR23_out[22] ^ LFSR23_out[21] ^ LFSR23_out[20] ^ LFSR23_out[7];

	// mux back into LFSR inputs
	my_tri #(1) LFSR19loadin_tristate_load(.in(LFSR19xor_out ^ loadin),.enable(stageone|stagetwo),.out(LFSR19_in));
	my_tri #(1) LFSR19loadin_tristate_run(.in(LFSR19xor_out),.enable(stagethree|outputstage),.out(LFSR19_in));
	my_tri #(1) LFSR22loadin_tristate_load(.in(LFSR22xor_out ^ loadin),.enable(stageone|stagetwo),.out(LFSR22_in));
	my_tri #(1) LFSR22loadin_tristate_run(.in(LFSR22xor_out),.enable(stagethree|outputstage),.out(LFSR22_in));
	my_tri #(1) LFSR23loadin_tristate_load(.in(LFSR23xor_out ^ loadin),.enable(stageone|stagetwo),.out(LFSR23_in));
	my_tri #(1) LFSR23loadin_tristate_run(.in(LFSR23xor_out),.enable(stagethree|outputstage),.out(LFSR23_in));

	// assign final output
	assign a51out = LFSR23_out[22] ^ LFSR22_out[21] ^ LFSR19_out[18];
endmodule

/***
Linear Feedback Shift Register
EXAMPLE 6 bit LFSR: [input ⇒ 0 ⇒ 1 ⇒ 2 ⇒ 3 ⇒ 4 ⇒ 5 ⇒ output]
***/
module LFSR(clk,in,out,write_enable,clrn,prn);
	parameter DATA_WIDTH = 32;
	input clk, in, write_enable;
	input [DATA_WIDTH-1:0] clrn, prn;
	output [DATA_WIDTH-1:0] out;
	wire n_to_np1[DATA_WIDTH:0];
	assign n_to_np1[0] = in;
	genvar c;
	generate
		for (c = 0; c < DATA_WIDTH; c = c + 1) begin: loopDFFs
			DFFE my_dff(.d(n_to_np1[c]),.clrn(clrn[c]),.prn(prn[c]),.clk(clk),.q(n_to_np1[c+1]),.ena(write_enable));
			assign out[c] =	n_to_np1[c+1];
		end
	endgenerate
endmodule

/***
3 bit majority function - return majority bit out of 3 input bits.
used in irregular clocking of a51_keygen
***/
module majority3 (x1, x2, x3, f);
	input x1, x2, x3;
	output f;
	assign f = (x1 & x2) | (x1 & x3) | (x2 & x3);
endmodule
