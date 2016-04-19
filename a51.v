module inputToA51(clk,reset,keyindex,dataindex,key,data,enterToKeyNotData, startKeyStreamGen);
	input startKeyStreamGen; // Flip Switch
	input enterToKeyNotData; // Another flip switch
	input [2:0] keyindex;
	input [4:0] dataindex;
	input [7:0] key, data; //eventually from PS2 TODO, can simulate using modelsim for nnow
	input clk, reset;

	// Instantiate special register stores for key+frame (86 bits) and message (224 bits). These registers are special as
	// They allow the writing of 8 bits at a time into different indices. They are controlled by a counter which increments
	// Its count every time there is a new keypress.
	// key + frame eventually piped into a LFSR, where it is then piped into a51 unit
	wire [63:0] keyframe_out;
	wire [223:0] datastore_out;
	keyframe_reg key(.ps2data_in(key), .keyindex(keyindex), .keyframe_out(keyframe_out), .write_enable(enterToKeyNotData), .clk(clk), .reset(reset));
	datastore_reg data(.ps2data_in(data), .index(dataindex), .datastore_out(datastore_out), .write_enable(~enterToKeyNotData), .clk(clk), .reset(reset));

	// instantiate keyframeLFSR, this will take input from our keyframe_reg
	wire[85:0] keyframeLFSR_out, keyframeLFSR_prn, keyframeLFSR_clrn;
	wire firstCycle = &(counter_out~^10'b0000000000);
	my_tri #(86) keyframeLFSRprntri(.in({keyframe_out,22'h000134}),.enable(firstCycle),.out(keyframeLFSR_prn));
	my_tri #(86) keyframeLFSRprntri2(.in({86{1'b0}}),.enable(~firstCycle),.out(keyframeLFSR_prn));
	my_tri #(86) keyframeLFSRclrntri(.in({keyframe_out,22'h000134}),.enable(firstCycle),.out(keyframeLFSR_clrn));
	my_tri #(86) keyframeLFSRclrntri2(.in({86{1'b1}}),.enable(~firstCycle),.out(keyframeLFSR_clrn));
	assign testout = keyframeLFSR_out;
	wire keyframeLFSR_in;
	assign keyframeLFSR_in = 1'bz;
	LFSR #(86) keyframeLFSR(clk,keyframeLFSR_in,keyframeLFSR_out,1'b1,keyframeLFSR_clrn,~keyframeLFSR_prn);

	a51 mya51(clk,reset, loadin, startKeyStreamGen, a51out,r19out,r22out,r23out, testout)

endmodule

// This is all the internal a51 logic, it starts operating when @startKeyStreamGen is asserted. Last four parameters are testing.
module a51(clk,reset, loadin, startKeyStreamGen, a51out,r19out,r22out,r23out, testout); // T
	input reset;
	input clk; // T
	input startKeyStreamGen;
	output a51out; // final output bit by bit of the A5/1
	output[18:0] r19out; // outputs of each LFSR in A5/1
	output [21:0] r22out;
	output [22:0] r23out;
	output [85:0] testout; // allow us to view our input key and frame bits
	wire loadin; // T

	//INPUT to keyframe and datastore registers



	// instantiate counter, this will be the "pulse" of the A5/1 cipher encrypt/decrypt unit.
	// we know that the A5/1 cipher setup has 4 stages: 64 cycle key xor, 22 cycle frame xor
	// 100 cycle irregular clocking and 224 cycles of valid output. these lines will be asserted
	// whenever the respective stage is true
	wire stageone,stagetwo,stagethree,outputstage;
	wire [9:0] counter_out;
	up_counter myCounter(.C(clk), .CLR(reset), .Q(counter_out), .ENABLE(startKeyStreamGen) , .STAGEONE(stageone), .STAGETWO(stagetwo), .STAGETHREE(stagethree),.OUTPUTSTAGE(outputstage));
	assign loadin = keyframeLFSR_out[85];

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
	LFSR #(19) LFSR19(clk,LFSR19_in,LFSR19_out,((clock19&(stagethree|outputstage))|(stageone|stagetwo)),{19{1'b1}},{19{1'b1}});
	wire LFSR22_in;
	LFSR #(22) LFSR22(clk,LFSR22_in,LFSR22_out,((clock22&(stagethree|outputstage))|(stageone|stagetwo)),{22{1'b1}},{22{1'b1}});
	wire LFSR23_in;
	LFSR #(23) LFSR23(clk,LFSR23_in,LFSR23_out,((clock23&(stagethree|outputstage))|(stageone|stagetwo)),{23{1'b1}},{23{1'b1}});

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

// OTHER MODULES

// Linear Feedback Shift Register
// EXAMPLE 6 bit LFSR: [input ⇒ 0 ⇒ 1 ⇒ 2 ⇒ 3 ⇒ 4 ⇒ 5 ⇒ output]
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

// standard variable width tristate buffer
module my_tri(in, enable, out);
	parameter DATA_WIDTH = 32;
	input [DATA_WIDTH-1:0]in;
	input enable;
	output [DATA_WIDTH-1:0]out;
	assign out = enable ? in : {DATA_WIDTH{1'bz}};
endmodule

// 3 bit majority function - return majority bit out of 3 input bits.
module majority3 (x1, x2, x3, f);
	input x1, x2, x3;
	output f;
	assign f = (x1 & x2) | (x1 & x3) | (x2 & x3);
endmodule
