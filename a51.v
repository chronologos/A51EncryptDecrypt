// module a51(clk,loadin,a51out,r19out,r22out,r23out, testout);
	// input clk, loadin;
module a51(clk,reset,a51out,r19out,r22out,r23out, testout); // T
	input reset;
	input clk; // T
	output a51out; // final output bit by bit of the A5/1
	output[18:0] r19out; // outputs of each LFSR in A5/1
	output [21:0] r22out;
	output [22:0] r23out;
	output [85:0] testout; // allow us to view our input key and frame bits
	wire loadin; // T

	// instantiate counter, this will be the "pulse" of the A5/1 cipher encrypt/decrypt unit.
	// we know that the A5/1 cipher setup has 4 stages: 64 cycle key xor, 22 cycle frame xor
	// 100 cycle irregular clocking and 224 cycles of valid output. these lines will be asserted
	// whenever the respective stage is true
	wire stageone,stagetwo,stagethree,outputstage;
	wire [9:0] counter_out;
	up_counter myCounter(.C(clk), .CLR(reset), .Q(counter_out), .STAGEONE(stageone), .STAGETWO(stagetwo), .STAGETHREE(stagethree),.OUTPUTSTAGE(outputstage));
	// instantiate testing lfsr
	wire[85:0] LFSRtest_out, LFSRtest_prn, LFSRtest_clrn;
	wire firstCycle = &(counter_out~^10'b0000000000);
	my_tri #(86) LFSRtestprntri(.in({64'h1223456789ABCDEF,22'h000134}),.enable(firstCycle),.out(LFSRtest_prn));
	my_tri #(86) LFSRtestprntri2(.in({86{1'b0}}),.enable(~firstCycle),.out(LFSRtest_prn));
	my_tri #(86) LFSRtestclrntri(.in({64'h1223456789ABCDEF,22'h000134}),.enable(firstCycle),.out(LFSRtest_clrn));
	my_tri #(86) LFSRtestclrntri2(.in({86{1'b1}}),.enable(~firstCycle),.out(LFSRtest_clrn));
	assign testout = LFSRtest_out;
	wire LFSRtest_in;
	assign LFSRtest_in = 1'bz;
	LFSR #(86) LFSRtest(clk,LFSRtest_in,LFSRtest_out,1'b1,LFSRtest_clrn,~LFSRtest_prn);
	assign loadin = LFSRtest_out[85];

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
