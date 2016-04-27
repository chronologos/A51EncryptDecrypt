/***
ECE350 Final Project
5 Stage Pipelined, Full Bypass Processor with parallel A5/1 Stream Cipher Unit
2016, Yi Yan Tay, Anthony Yu
***/
module yt61_hw5(inclock, resetn, ps2_clock, ps2_data, a51_enterToKeyNotData, a51_startKeyStreamGen,
								/**debug_word, debug_addr**/,
								lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon, sevensegout1, sevensegout2, sevensegout3,
								LED17, LED16, LED15, LED14, LED13);

	input inclock, resetn;
	input ps2_data, ps2_clock;
	input a51_enterToKeyNotData, a51_startKeyStreamGen; //inputs to a51 from IO

	output lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon;
	output [7:0] lcd_data;
	// output [31:0] debug_word;
	// output [11:0] debug_addr;
	output[6:0] sevensegout1, sevensegout2, sevensegout3;
	output LED17, LED16, LED15, LED14, LED13;

	wire clock;
	wire lcd_write_en;
	wire [31:0] lcd_write_data; // TODO
	wire [7:0] ps2_key_data;
	wire ps2_key_pressed;
	wire [7:0]	ps2_out; // TODO


	wire [3:0] a51_keyindex; //from a51 to hex display
	wire [4:0] a51_dataindex; //from a51 to hex display

	// clock divider (by 5, i.e., 10 MHz)
	// pll div(inclock,clock);
	// UNCOMMENT FOLLOWING LINE AND COMMENT ABOVE LINE TO RUN AT 50 MHz

	assign clock = inclock;

	/**
		__    ___    _  __
	 / _\  / __)  / )/  \
	/    \(___ \ / /(_/ /
	\_/\_/(____/(_/  (__)
	**/
	wire a51_enable_from_processor, a51_done, a51_reset; //processor to a51 and back

	//a51 to IO and back
	wire a51_lcd_reset, a51_lcd_enable;
	wire [7:0] a51_lcd_data;
	wire [127:0] keystream_to_processor_wire;
	// TODO enable
	a51 myA51(.clk(clock), .reset(~resetn), .enable(a51_enable_from_processor | 1'b1), .enterToKeyNotData(a51_enterToKeyNotData), .startKeyStreamGen(a51_startKeyStreamGen), .ps2_key_pressed(ps2_key_pressed), .ps2_key_data(ps2_key_data), .LEDerror(LED14), .LEDenterToKeyNotData(LED17), .LEDstartKeyStreamGen(LED16), .LEDKeyStreamDepleted(LED15), .LEDmessage_to_lcd_done(a51_done), .keyindex_out(a51_keyindex), .dataindex_out(a51_dataindex), .data_to_lcd_out(a51_lcd_data), .lcd_reset(a51_lcd_reset), .lcd_enable(a51_lcd_enable),.keystream_to_processor(keystream_to_processor_wire));

	assign LED13 = a51_done;

	processor myprocessor(clock, ~resetn, ps2_key_pressed, ps2_out, lcd_write_en, lcd_write_data, debug_word, debug_addr, a51_enable_from_processor, a51_done, a51_reset, keystream_to_processor_wire);


	/**
	__      _     __
 (  )    / )   /  \
  )(    / /   (  O )
 (__)  (_/     \__/
	**/

	PS2_Interface myps2(clock, resetn, ps2_clock, ps2_data, ps2_key_data, ps2_key_pressed, ps2_out);

	lcd mylcd(clock, ~resetn | a51_lcd_reset, lcd_write_en | a51_lcd_enable, a51_lcd_data, lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon);

	Hexadecimal_To_Seven_Segment counter(a51_keyindex,sevensegout3);
	Hexadecimal_To_Seven_Segment counter2(a51_dataindex[3:0],sevensegout2);
	Hexadecimal_To_Seven_Segment counter3({{3'b0,a51_dataindex[4]}},sevensegout1);

endmodule

// -----------------------------
// ---- your processor here ----
// -----------------------------

module processor(clock, reset, ps2_key_pressed, ps2_out, lcd_write, lcd_data, debug_data, debug_addr, a51_en, a51_done, a51_reset, a51_keystream_in);

	input clock, reset, ps2_key_pressed, a51_done;
	input [7:0]	ps2_out;
	input [127:0] a51_keystream_in;
	output lcd_write;
	output [31:0] lcd_data;
	// GRADER OUTPUTS - YOU MUST CONNECT TO YOUR DMEM
	output [31:0] debug_data;
	output [11:0] debug_addr;
	output a51_en, a51_reset;


	wire[31:0] STATUS_in,STATUS_out;
	wire setx, statusgtz, multdiv_exception; // for bex setx
	yt61_reg STATUS(.reg_d(STATUS_in),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),
									.reg_f(STATUS_out),.write_enable(setx|multdiv_exception),.clk(clock));
	assign statusgtz = (~STATUS_out[31]) & (|STATUS_out[30:0]); // gtz if msb is 0 and other bits contain at least one 1

	// --------
	// -- F --
	//---------
	// PC
	wire[31:0] FD_PC_STORE_out, PC_out, PC_PLUS1_out, PC_in, branchAddr; //branchALU is in XM but used here
	wire[31:0] FD_IR_out, DX_IR_out, XM_IR_out, MW_IR_out; // instruction store for each pipeline register
	wire useless_PCALUisNotEqual2, useless_PCALUisLessThan;
	wire mainALUisNotEqual, mainALUisLessThan;

	// --- BRANCH LOGIC, SHOULD BELONG IN DX STAGE ---
	// 3 controls for 3 branches. BLT(opcode 00110) BNE(opcode 00010) BEQ (opcode 10110).
	wire bne = &(DX_IR_out[31:27] ^~ 5'b00010);
	wire blt = &(DX_IR_out[31:27] ^~ 5'b00110);
	wire bex = &(DX_IR_out[31:27] ^~ 5'b10110);

	// ------
	// Branch Predictor
	// ------
	wire[31:0] BP_out, imem_out, DX_PC_STORE_out, nextPC_mux_out, DX_TG_STORE_out;
	wire imem_out_is_branch = &(imem_out[31:27] ^~ 5'b00010) | &(imem_out[31:27] ^~ 5'b00110) | &(imem_out[31:27] ^~ 5'b10110); // use this to enable prediction for branch instructions only
	wire mispredicted; // assign to willBranch xor BP_branchtaken
	wire willBranch;
	branchPredictor myBP(.clock(~clock), .ctrl_writeEnable(bne|blt|bex), .ctrl_reset(reset), .ctrl_writeReg(DX_PC_STORE_out[4:0]), .ctrl_readRegA(nextPC_mux_out[4:0]), .data_writeReg({19'b0,willBranch,branchAddr[11:0]}), .data_readRegA(BP_out));
	//TODO

	// This part has two muxes and one AND gate.
	wire whichBranch;
	my_tri #(1) bltbnebex_mux1(mainALUisNotEqual, bne, whichBranch); //bne
	my_tri #(1) bltbnebex_mux2(~mainALUisLessThan & mainALUisNotEqual, blt, whichBranch); //blt
	my_tri #(1) bltbnebex_mux3(1'b0, ~(bne|blt|bex), whichBranch); // if none send 0
	my_tri #(1) bltbnebex_mux4(statusgtz, bex, whichBranch); //bex
	// another control to control another mux
	assign willBranch = whichBranch & ( bne | blt | bex ); // selector 1 if BNE|BLT|BEX ctrl is 1 & ALULT/ALUNE/STATUSGTZ is 1
	assign mispredicted = willBranch ^ DX_TG_STORE_out[12];

	// -- JUMP LOGIC --
	wire jjal = &(FD_IR_out[31:27] ^~ 5'b00001) | (&(FD_IR_out[31:27] ^~ 5'b00011)); // j or jal.
	wire jal =	&(FD_IR_out[31:27] ^~ 5'b00011); // jal
	wire jr = &(FD_IR_out[31:27] ^~ 5'b00100); //jr
	wire willJump = (jjal | jr);

	wire[31:0] JUMP_addr, regfile_RegB_out;
	wire stall;

	// mux to decide jump address
	my_tri immediateJump({{5{FD_IR_out[26]}},FD_IR_out[26:0]},jjal,JUMP_addr);
	my_tri regJump(regfile_RegB_out,jr,JUMP_addr);

	// Branch or next PC or Jump
	my_tri nextPC_mux1(branchAddr, willBranch, nextPC_mux_out);
	my_tri nextPC_mux2(PC_out, ~willJump & ~willBranch, nextPC_mux_out);
	my_tri nextPC_mux3(JUMP_addr, willJump & ~willBranch, nextPC_mux_out);
	// assign PC_in = PC_PLUS1_out;
	wire[31:0] bpmux_out;
	assign PC_in = bpmux_out;

	my_tri branchPredictor_mux1(PC_PLUS1_out,~(BP_out[12] & imem_out_is_branch),bpmux_out); //BP predicts not taken, send PC+1 to TG
	my_tri branchPredictor_mux2(BP_out,BP_out[12] & imem_out_is_branch,bpmux_out); // BP predicts taken, send predicted path to TG

	yt61_reg PC(.reg_d(PC_in),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(PC_out),.write_enable(~stall),.clk(clock));
	yt61_alu PC_ALU(.data_operandA(nextPC_mux_out), .data_operandB(32'b1), .ctrl_ALUopcode(5'b00000), .ctrl_shiftamt(5'b00000), .data_result(PC_PLUS1_out), .isNotEqual(useless_PCALUisNotEqual2), .isLessThan(useless_PCALUisLessThan));

	// branch flush logic: noop mux
	// wire flush = willBranch; //control whether FD and DX flush.
	wire flush = mispredicted;
	wire[31:0] FD_IR_in = imem_out;

	// FD Pipeline Reg
	yt61_reg FD_PC_STORE(.reg_d(PC_PLUS1_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(FD_PC_STORE_out),.write_enable(~stall),.clk(clock));
	yt61_reg FD_INSTR_STORE(.reg_d(FD_IR_in),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(FD_IR_out),.write_enable(~stall),.clk(clock)); // this will propagate through all pipeline stages and be stoerd in respective pipeline registers
	// for branch prediction, TODO
	wire[31:0] FD_TG_STORE_out;
	yt61_reg FD_TG_STORE(.reg_d(bpmux_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(FD_TG_STORE_out),.write_enable(~stall),.clk(clock));

	// --------
	// -- D --
	//---------
	// Regfile
	wire [31:0] regfile_RegA_out, regfile_RegWrite_in;
	wire [31:0] DX_REGA_STORE_out, DX_REGB_STORE_out; //dx_pc_store_out is used in branch predictor

	wire RegWrite = &(MW_IR_out[31:27] ^~ 5'b00000) | &(MW_IR_out[31:27] ^~ 5'b00101) | &(MW_IR_out[31:27] ^~ 5'b01000) | &(MW_IR_out[31:27] ^~ 5'b00011);
	//RegWrite when opcode is 00000, 00101 (addi) or 01000 (lw) or 00011 (jal)

	// choose regB
	wire[4:0] regB_choose;
	wire regBisRD = &(FD_IR_out[31:27] ^~ 5'b00010)| &(FD_IR_out[31:27] ^~ 5'b00110) | &(FD_IR_out[31:27] ^~ 5'b00111) | (&(FD_IR_out[31:27] ^~ 5'b00100)); // for blt, bne, sw, jr
	my_tri #(5) regB_is_rd(FD_IR_out[26:22], regBisRD,regB_choose);
	my_tri #(5) regB_is_rt(FD_IR_out[16:12], ~regBisRD,regB_choose);

	wire jalInWB = &(MW_IR_out[31:27] ^~ 5'b00011); // jal
	wire[4:0] writeReg_choose; // write to RD or $R31
	wire[31:0] multdiv_IR_out;
	wire multdiv_ready_latch_out;
	my_tri #(5) writeReg_is_normal(MW_IR_out[26:22],~(jalInWB|multdiv_ready_latch_out),writeReg_choose); // write to normal RD
	my_tri #(5) writeReg_is_r31(5'b11111,jalInWB,writeReg_choose); // write to $R31
	my_tri #(5) writeReg_is_multdiv(multdiv_IR_out[26:22],multdiv_ready_latch_out,writeReg_choose); // multdiv returned result, use instruction stored in multdiv IR latch

	wire[31:0] regfiledebug0, regfiledebug1, regfiledebug2, regfiledebug3, regfiledebug4, regfiledebug5, regfiledebug6, regfiledebug7, regfiledebug31;

	regfile my_regfile(.clock(~clock), .ctrl_writeEnable(RegWrite), .ctrl_reset(reset), .ctrl_writeReg(writeReg_choose), .ctrl_readRegA(FD_IR_out[21:17]), .ctrl_readRegB(regB_choose), .data_writeReg(regfile_RegWrite_in), .data_readRegA(regfile_RegA_out), .data_readRegB(regfile_RegB_out),.data_out0(regfiledebug0),.data_out1(regfiledebug1),.data_out2(regfiledebug2),.data_out3(regfiledebug3),.data_out4(regfiledebug4),.data_out5(regfiledebug5),.data_out6(regfiledebug6), .data_out7(regfiledebug7),.data_out31(regfiledebug31));

	// stall and branch flush logic: noop mux
	wire[31:0] DX_IR_in, DX_PC_in;
	my_tri nostallmuxDXIR(FD_IR_out, ~(stall | flush), DX_IR_in);
	my_tri stallmuxDXIR(32'b0, (stall | flush), DX_IR_in); //Write nop into D/X.IR

	my_tri nostallmuxDXPC(FD_PC_STORE_out, ~(stall | flush), DX_PC_in);
	my_tri stallmuxDXPC(32'b0, (stall | flush), DX_PC_in); //Write nop into D/X.IR

	/***

	A5/1 Launching and Stalling

	When opcode 11111 (a51start) is in decode stage and ~a51_done we stall. a51_en is asserted as long as a51start is in decode stage. a51 unit will run for X cycles. when a51 unit is done it will assert a51_done. Unit will unstall and a51_en will be false.

	***/
	wire A51Start = &(FD_IR_out[31:27] ^~ 5'b11111); // CUSTOM INSTRUCTION
	assign a51_en = A51Start;

	// DX Pipeline Reg
	yt61_reg DX_INSTR_STORE(.reg_d(DX_IR_in),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(DX_IR_out),.write_enable(1'b1),.clk(clock));
	yt61_reg DX_REGA_STORE(.reg_d(regfile_RegA_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(DX_REGA_STORE_out),.write_enable(1'b1),.clk(clock));
	yt61_reg DX_REGB_STORE(.reg_d(regfile_RegB_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(DX_REGB_STORE_out),.write_enable(1'b1),.clk(clock));
	yt61_reg DX_PC_STORE(.reg_d(DX_PC_in),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(DX_PC_STORE_out),.write_enable(1'b1),.clk(clock));
	yt61_reg DX_TG_STORE(.reg_d(BP_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(DX_TG_STORE_out),.write_enable(1'b1),.clk(clock));


	// --------
	// -- X --
	//---------
	wire[31:0] sign_extended_immediate = {{15{DX_IR_out[16]}},DX_IR_out[16:0]}; // 17 bit immediate sign extended
	// ALUs
	wire[31:0] mainALU_operandA_in, mainALU_operandB_in, mainALU_out;
	// INSTRUCTIONS: BNE, BLT
	wire BranchAddercout, BranchAdderlastcin;
	Adder32 branchAdder(.aaa(DX_PC_STORE_out),.bbb(sign_extended_immediate),.sss(branchAddr),.subtract(1'b0),.cccout(BranchAddercout),.lastCarryin4(BranchAdderlastcin)); // PC + N

	// Adder32 branchAdder2(.aaa(branchadder1out),.bbb(32'b1),.sss(branchAddr),.subtract(1'b0),.cccout(BranchAddercout2),.lastCarryin4(BranchAdderlastcin2)); // PC + N + 1

	//control opcode for the main ALU
	wire[4:0] mainALU_opcode_in;
	wire RType = &(DX_IR_out[31:27] ^~ 5'b00000);

	my_tri #(5) aluopcodemux1(DX_IR_out[6:2], RType, mainALU_opcode_in); // RType = 1, regB used, use ALUOp field
	my_tri #(5) aluopcodemux2(5'b00000, ~(RType | bne | blt), mainALU_opcode_in); // use add opcode
	my_tri #(5) aluopcodemux3(5'b00001, bne | blt, mainALU_opcode_in); // use sub opcode for branches so that ALU output for NE and LT are relevant.

	yt61_alu mainALU(.data_operandA(mainALU_operandA_in), .data_operandB(mainALU_operandB_in), .ctrl_ALUopcode(mainALU_opcode_in), .ctrl_shiftamt(DX_IR_out[11:7]), .data_result(mainALU_out), .isNotEqual(mainALUisNotEqual), .isLessThan(mainALUisLessThan));

	// Custom OP to load keystream into register
	wire [31:0] toXM_alustore;
	wire [31:0] keystream_part;

	// RS determines which part of keystream to load
	my_tri #(32) a51_keystream_mux1(a51_keystream_in[31:0],&(DX_IR_out[21:17]~^5'b00000),keystream_part);
	my_tri #(32) a51_keystream_mux2(a51_keystream_in[63:32],&(DX_IR_out[21:17]~^5'b00001),keystream_part);
	my_tri #(32) a51_keystream_mux3(a51_keystream_in[95:64],&(DX_IR_out[21:17]~^5'b00010),keystream_part);
	my_tri #(32) a51_keystream_mux4(a51_keystream_in[127:96],&(DX_IR_out[21:17]~^5'b00011),keystream_part);
	k
	my_tri #(32) loadkeystreamtri1(keystream_part,&(DX_IR_out[6:2]~^5'b01001) & RType,toXM_alustore);
	my_tri #(32) loadkeystreamtri2(mainALU_out,~(&(DX_IR_out[6:2]~^5'b01001) & RType),toXM_alustore);

	// data_operandA bypass logic control signals
	wire XMnotJType = ~(&(XM_IR_out[31:27] ^~ 5'b00001) | &(XM_IR_out[31:27] ^~ 5'b00011) | &(XM_IR_out[31:27] ^~ 5'b00100) | &(XM_IR_out[31:27] ^~ 5'b10110) | &(XM_IR_out[31:27] ^~ 5'b10101));
	wire MWnotJType = ~(&(MW_IR_out[31:27] ^~ 5'b00001) | &(MW_IR_out[31:27] ^~ 5'b00011) | &(MW_IR_out[31:27] ^~ 5'b00100) | &(MW_IR_out[31:27] ^~ 5'b10110) | &(MW_IR_out[31:27] ^~ 5'b10101));
	wire MWaffectsRD = &(MW_IR_out[31:27] ^~ 5'b00000) | &(MW_IR_out[31:27] ^~ 5'b01000) | &(MW_IR_out[31:27] ^~ 5'b00101) ; // r type and lw and addi
	wire ALUopA_XMstore = &(DX_IR_out[21:17] ^~ XM_IR_out[26:22]) & XMnotJType & ~(&(DX_IR_out[21:17] ^~  5'b00000));
	wire ALUopA_regwrite = (&(DX_IR_out[21:17] ^~ MW_IR_out[26:22])) & ~ALUopA_XMstore & MWnotJType & ~(&(DX_IR_out[21:17] ^~  5'b00000)) & MWaffectsRD; //deviate from slides because if both DX-XM and DX-MY bypass conditions are true, we take the newest bypass (XM), also we need to check that the older instructions are not J type.
	wire ALUopA_normal = ~(ALUopA_XMstore | ALUopA_regwrite);

	// data_operandB bypass logic control signals, this is more complex than data_operandA because operandA can only have RS while operandB can hold rt or rd
	wire rd_used_as_input_in_X = &(DX_IR_out[31:27] ^~ 5'b00010) | &(DX_IR_out[31:27] ^~ 5'b00110) | &(DX_IR_out[31:27] ^~ 5'b00111); //bne blt sw use $rd
	wire ALUopB_XMstore = ((&(DX_IR_out[16:12] ^~ XM_IR_out[26:22]) & ~(&(DX_IR_out[16:12] ^~  5'b00000))) | (&(DX_IR_out[26:22] ^~ XM_IR_out[26:22]) & rd_used_as_input_in_X & ~(&(DX_IR_out[26:22] ^~  5'b00000)))) & XMnotJType;
	wire ALUopB_regwrite = ((&(DX_IR_out[16:12] ^~ MW_IR_out[26:22]) & ~(&(DX_IR_out[16:12] ^~  5'b00000))) | (&(DX_IR_out[26:22] ^~ MW_IR_out[26:22]) & rd_used_as_input_in_X & ~(&(DX_IR_out[26:12] ^~  5'b00000))))  & ~ALUopB_XMstore & MWnotJType & MWaffectsRD;
	wire ALUopB_normal = ~(ALUopB_XMstore | ALUopB_regwrite);

	// ctrl: sign extend or take reg value
	wire[31:0] opB_bypass_out;
	my_tri mainALU_operandB_mux1(opB_bypass_out, (RType | bne | blt), mainALU_operandB_in); // if RType = 1, use regB
	my_tri mainALU_operandB_mux2(sign_extended_immediate, ~(RType | bne | blt), mainALU_operandB_in); // RType = 0, use sign extended immediate

	// ctrl: data_operandA bypass
	wire[31:0] XM_mainALU_STORE_out;
	my_tri ALUopA_bypass1(DX_REGA_STORE_out, ALUopA_normal, mainALU_operandA_in);
	my_tri ALUopA_bypass2(XM_mainALU_STORE_out, ALUopA_XMstore, mainALU_operandA_in);
	my_tri ALUopA_bypass3(regfile_RegWrite_in, ALUopA_regwrite, mainALU_operandA_in);

	// ctrl: data_operandB bypass
	my_tri ALUopB_bypass1(DX_REGB_STORE_out, ALUopB_normal ,opB_bypass_out);
	my_tri ALUopB_bypass2(XM_mainALU_STORE_out, ALUopB_XMstore, opB_bypass_out);
	my_tri ALUopB_bypass3(regfile_RegWrite_in, ALUopB_regwrite, opB_bypass_out);

	//ctrl for setx opcode (10101)
	assign setx = &(FD_IR_out[31:27] ^~ 5'b10101);
	assign STATUS_in = {{5{FD_IR_out[26]}},FD_IR_out[26:0]}; //we want to preserve the sign of 32 bit status register so we sign extend with 5 MSB

	// Pipeline Reg
	wire[31:0] XM_REGB_STORE_out, XM_PC_STORE_out;
	wire ctrlMult, ctrlDiv;
	// if instruction in X stage is mult or div we make the replace the propagating instruction with a noop
	yt61_reg XM_INSTR_STORE(.reg_d((ctrlMult|ctrlDiv)?{32{1'b0}}:DX_IR_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(XM_IR_out),.write_enable(1'b1),.clk(clock));
	yt61_reg XM_REGB_STORE(.reg_d(opB_bypass_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(XM_REGB_STORE_out),.write_enable(1'b1),.clk(clock));
	yt61_reg XM_mainALU_STORE(.reg_d(mainALU_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(toXM_alustore),.write_enable(1'b1),.clk(clock));
	yt61_reg XM_PC_STORE(.reg_d(DX_PC_STORE_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(XM_PC_STORE_out),.write_enable(1'b1),.clk(clock));

	// --------
	// -- M --
	//---------

	// Pipeline Reg
	wire[31:0] dmem_data_out, MW_mainALU_STORE_out, MW_dmem_STORE_out, MW_PC_STORE_out;
	//ctrl for sw opcode (00111)
	wire MemWrite = &(XM_IR_out[31:27] ^~ 5'b00111);
	//memwrite when opcode is 00111(sw)
	yt61_reg MW_INSTR_STORE(.reg_d(XM_IR_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(MW_IR_out),.write_enable(1'b1),.clk(clock));
	yt61_reg MW_mainALU_STORE(.reg_d(XM_mainALU_STORE_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(MW_mainALU_STORE_out),.write_enable(1'b1),.clk(clock));
	yt61_reg MW_dmem_STORE(.reg_d(dmem_data_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(MW_dmem_STORE_out),.write_enable(1'b1),.clk(clock));
	yt61_reg MW_PC_STORE(.reg_d(XM_PC_STORE_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(MW_PC_STORE_out),.write_enable(1'b1),.clk(clock));

	//WM bypass logic control signals
	wire WM_bypass = (&(XM_IR_out[26:22] ^~ MW_IR_out[26:22])) & (&(XM_IR_out[31:27] ^~ 5'b00111)) & (&(MW_IR_out[31:27] ^~ 5'b01000)); // if rd in XM SW instruct = rd in MW LW instruct

	// ctrl: WM bypass
	wire[31:0] dmem_data_in;
	my_tri dmem_bypass1(XM_REGB_STORE_out, ~WM_bypass ,dmem_data_in);
	my_tri dmem_bypass2(regfile_RegWrite_in, WM_bypass, dmem_data_in);


	// --------
	// -- W --
	//---------
	//ctrl for lw opcode (01000)
	wire[31:0] multdiv_RESULT_STORE_out;
	wire MemtoReg = ~MW_IR_out[31] & MW_IR_out[30] & ~MW_IR_out[29] & ~MW_IR_out[28] & ~MW_IR_out[27];
	my_tri regwrite_mux1(MW_mainALU_STORE_out, ~(MemtoReg|jalInWB|multdiv_ready_latch_out), regfile_RegWrite_in); // for r type write to rd
	my_tri regwrite_mux2(MW_dmem_STORE_out, MemtoReg, regfile_RegWrite_in); //for lw
	my_tri regwrite_mux3(MW_PC_STORE_out, jalInWB, regfile_RegWrite_in); // for storing pc+1 for JAL
	my_tri regwrite_mux4(multdiv_RESULT_STORE_out, multdiv_ready_latch_out, regfile_RegWrite_in); //for storing multdiv result

	//------
	// Multiplier / Divider
	//------
	assign ctrlMult = RType & &(DX_IR_out[6:2] ^~ 5'b00110);
	assign ctrlDiv = RType & &(DX_IR_out[6:2] ^~ 5'b00111);
	wire[31:0] multdiv_out;
	wire multdiv_inputrdy, multdiv_resultrdy;
	yt61_hw4 myMultDiv(.data_operandA(mainALU_operandA_in), .data_operandB(mainALU_operandB_in), .ctrl_MULT(ctrlMult), .ctrl_DIV(ctrlDiv), .clock(clock), .data_result(multdiv_out), .data_exception(multdiv_exception), .data_inputRDY(multdiv_inputrdy), .data_resultRDY(multdiv_resultrdy));
	yt61_reg multdiv_INSTR_STORE(.reg_d(DX_IR_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(multdiv_IR_out),.write_enable(ctrlMult|ctrl_DIV),.clk(clock));
	yt61_reg multdiv_RESULT_STORE(.reg_d(multdiv_out),.reg_prn({32{1'b1}}),.reg_clrn({32{~reset}}),.reg_f(multdiv_RESULT_STORE_out),.write_enable(multdiv_resultrdy),.clk(clock));
	wire multdiv_active;
	DFFE multdiv_ready_latch(.d(multdiv_resultrdy),.clk(clock),.clrn(~reset),.prn(1'b1),.ena(1'b1),.q(multdiv_ready_latch_out));
	TFFE multdivactive (.t(ctrlMult | ctrlDiv | multdiv_resultrdy), .clk(clock), .clrn(~reset), .prn(1'b1), .ena(1'b1), .q(multdiv_active));

	/***
		____  ____  __   __    __      __     __    ___  __  ___
	 / ___)(_  _)/ _\ (  )  (  )    (  )   /  \  / __)(  )/ __)
	 \___ \  )( /    \/ (_/\/ (_/\  / (_/\(  O )( (_ \ )(( (__
	 (____/ (__)\_/\_/\____/\____/  \____/ \__/  \___/(__)\___)
	***/

	wire rs2matters = (&(FD_IR_out[31:27] ^~ 5'b00000)) & ~(&(FD_IR_out[31:28] ^~ 4'b0010));
	wire stall1 = &(DX_IR_out[31:27] ^~ 5'b01000) & ((&(FD_IR_out[21:17] ^~ DX_IR_out[26:22])) | ((&(FD_IR_out[16:12] ^~ DX_IR_out[26:22])) & rs2matters));
	// assign stall2 = (ctrlMult | ctrlDiv) & ~multdiv_inputrdy; // stall if mult/div operation at DX but multdiv unit not ready to operate.
	wire stall3= multdiv_active & ~multdiv_resultrdy;
	assign stall = stall1 | stall3 | (A51Start & ~a51_done);

	//where RS2matters means the insn is R type and not shift
	//stall when DX is load & ((FD.RS1 == DX.RD) || ((FD.RS2 == DX.RD) & RS2matters))

	// end of my processor

	//////////////////////////////////////
	////// THIS IS REQUIRED FOR GRADING
	// CHANGE THIS TO ASSIGN YOUR DMEM WRITE ADDRESS ALSO TO debug_addr
	assign debug_addr = XM_mainALU_STORE_out[11:0];
	// CHANGE THIS TO ASSIGN YOUR DMEM DATA INPUT (TO BE WRITTEN) ALSO TO debug_data
	assign debug_data = dmem_data_in;
	////////////////////////////////////////////////////////////
	// You'll need to change where the dmem and imem read and write...
	dmem mydmem(.address(XM_mainALU_STORE_out[11:0]), .clock(~clock), .data(dmem_data_in), .wren(MemWrite), .q(dmem_data_out)); // change where output q goes...


	imem myimem(.address(nextPC_mux_out[11:0]), .clken(1'b1), .clock(~clock), .q(imem_out) );

endmodule

//************************************************************
//										 OTHER MODULES USED
//************************************************************

//multdiv
module yt61_hw4(data_operandA, data_operandB, ctrl_MULT, ctrl_DIV, clock, data_result, data_exception, data_inputRDY, data_resultRDY);
	input [31:0] data_operandA;
	input [15:0] data_operandB;
	input ctrl_MULT, ctrl_DIV, clock;
	output [31:0] data_result;
	output data_exception, data_inputRDY, data_resultRDY;

	//let T be time of mult/div assertion

	// mult or div? (T+1)
	wire mult_sr_out, div_sr_out, data_resultRDY_in, data_inputRDY_in, data_inputNOTRDY_in, regClear_out;
	DFFE mult_state (.d(ctrl_MULT), .clk(clock), .clrn(~regClear_out), .prn(1'b1), .ena(ctrl_MULT|regClear_out), .q(mult_sr_out));
	DFFE div_state (.d(ctrl_DIV), .clk(clock), .clrn(~regClear_out), .prn(1'b1), .ena(ctrl_DIV|regClear_out), .q(div_sr_out));

	// inputRDY logic
	wire[7:0] count_mult, count_div;
	assign data_inputRDY = data_inputRDY_in;
	assign data_inputRDY_in = ~data_inputNOTRDY_in;
	assign data_resultRDY = data_resultRDY_in;
	wire multRDY, divRDY;
	assign multRDY = &(8'b00100000~^count_mult);
	assign divRDY = &(8'b00100001~^count_div);
	assign data_resultRDY_in = (multRDY & mult_sr_out) | (divRDY & div_sr_out);

	// T - 2
	DFFE regclear_dff(.d(data_resultRDY_in),.clrn(1'b1),.prn(1'b1),.clk(clock),.q(regClear_out),.ena(1'b1)); //control when register for result is cleared, essentially delay element
	// T - 3 to T + 2
	TFFE inputNOTRDY_ff(.t(regClear_out),.clk(clock),.q(data_inputNOTRDY_in),.prn(~(mult_sr_out| div_sr_out)),.clrn(1'b1),.ena(1'b1)); // latch toggles to zero 1 cycle after resultRDY. it stays zero(ready) until mult_sr_out or div are asserted which presets to one(notready).

	//counter module up_counter(out, enable, clk, reset);
	//clock with main clock, reset when 32, enable when running, output current count to count_mult
	up_counter counter(count_mult,(mult_sr_out),clock,~(mult_sr_out));
	up_counter counter2(count_div,(div_sr_out),clock,~(div_sr_out));

	// track carry out of adder
	wire reg_carry_wire_out, reg_carry_wire_in; //DFF to ALU Cin to ALU Cout back to DFF
	DFFE carry_dff(.d(reg_carry_wire_in),.clrn(~regClear_out),.prn(1'b1),.clk(clock),.q(reg_carry_wire_out),.ena(1'b1));

	// sign storage DFFEs and multiplicand storage
	wire signA_dff_out, signB_dff_out, useless_addone_adder_cout, useless_addone_adder_lastcin, useless_addone_adder_cout2, useless_addone_adder_lastcin2;
	wire[15:0] mtplicnd_dvsor_reg_out,operandB_negated_plus_one,negated_multiplicand,mtplicnd_dvsor_in;
	wire[31:0] operandA_negated_plus_one,negated_multiplier,mtplr_dvdnd_in;
	assign negated_multiplicand = ~data_operandB;
	assign negated_multiplier = ~data_operandA;
	Adder16 add1_adder(negated_multiplicand,16'b1,operandB_negated_plus_one,1'b0,useless_addone_adder_cout,useless_addone_adder_lastcin);
	Adder32 add1_adder2(negated_multiplier,32'b1,operandA_negated_plus_one,1'b0,useless_addone_adder_cout2, useless_addone_adder_lastcin2);
	my_tri #(16) to_mtplicnd_dvsor_reg_1(operandB_negated_plus_one, data_operandB[15], mtplicnd_dvsor_in);//negative
	my_tri #(16) to_mtplicnd_dvsor_reg_2(data_operandB, ~data_operandB[15], mtplicnd_dvsor_in);//positive
	my_tri to_mtplr_dvdnd_register_1(operandA_negated_plus_one, data_operandA[31], mtplr_dvdnd_in);//negative
	my_tri to_mtplr_dvdnd_register_2(data_operandA, ~data_operandA[31], mtplr_dvdnd_in);//positive
	DFFE signA(.d(data_operandA[31]),.clrn(~regClear_out),.prn(1'b1),.clk(clock),.q(signA_dff_out),.ena(data_inputRDY_in & (ctrl_MULT | ctrl_DIV)));
	DFFE signB(.d(data_operandB[15]),.clrn(~regClear_out),.prn(1'b1),.clk(clock),.q(signB_dff_out),.ena(data_inputRDY_in & (ctrl_MULT | ctrl_DIV)));

	yt61_reg #(16) mtplicnd_dvsor(.reg_d(mtplicnd_dvsor_in),.reg_prn({16{1'b1}}),.reg_clrn(~{16{regClear_out}}),.reg_f(mtplicnd_dvsor_reg_out),.write_enable(data_inputRDY_in & (ctrl_MULT | ctrl_DIV)),.clk(clock));

	//register logic (divider)
	wire[47:0] shifter_in_div,shifter_out_div,shifter_out_div_with_quotient;
	wire[15:0] msb_to_shifter_div;
	wire[47:0] div_input_tri_in, div_input_tri2_in, remainder_reg_in, remainder_reg_out;
	assign div_input_tri_in = shifter_out_div_with_quotient;
	assign div_input_tri2_in = {{16{1'b0}},mtplr_dvdnd_in};
	my_tri #(48) tri_d1(div_input_tri_in, ~(data_inputRDY_in & ctrl_DIV), remainder_reg_in); // take subtracted value
	my_tri #(48) tri_d2(div_input_tri2_in, (data_inputRDY_in & ctrl_DIV), remainder_reg_in); //load new value from operand
	yt61_reg #(48) remainder(.reg_d(remainder_reg_in),.reg_prn({48{1'b1}}),.reg_clrn(~{48{regClear_out}}),.reg_f(remainder_reg_out),.write_enable(1'b1),.clk(clock));
	wire[31:0] remainder_reg_lsb;
	wire[31:0] remainder_reg_msb;
	assign remainder_reg_msb = {{16{1'b0}},remainder_reg_out[47:32]}; //pad with 0 in front as ALU is 32 bit
	assign remainder_reg_lsb = remainder_reg_out[31:0];

	//ALU for divider
	wire divider_isLessThan,divider_isNotEqual; // islessthan = A<B
	wire[31:0] dividerALU_out;
	yt61_alu dividerALU(remainder_reg_msb, {{16{1'b0}},mtplicnd_dvsor_reg_out}, 5'b00001, 5'b00001, dividerALU_out, divider_isNotEqual, divider_isLessThan);


	//shifter for div
	my_tri #(16) tri_subtract1(remainder_reg_msb[15:0], divider_isLessThan, msb_to_shifter_div);
	my_tri #(16) tri_subtract2(dividerALU_out[15:0], ~divider_isLessThan, msb_to_shifter_div);
	assign shifter_in_div = {msb_to_shifter_div,remainder_reg_lsb};
	assign shifter_out_div = shifter_in_div << 1;
	assign shifter_out_div_with_quotient = {shifter_out_div[47:1],~divider_isLessThan}; // where u actually assign value to quotient

	// register logic (mult)
	wire[47:0] shifter_out_mult,mult_input_tri_in, mult_input_tri2_in,product_reg_in, product_reg_out;
	assign mult_input_tri_in = shifter_out_mult;
	assign mult_input_tri2_in = {{16{1'b0}},mtplr_dvdnd_in};
	my_tri #(48) tri_m1(mult_input_tri_in, ~(data_inputRDY_in & ctrl_MULT), product_reg_in); // take shifter value
	my_tri #(48) tri_m2(mult_input_tri2_in, (data_inputRDY_in & ctrl_MULT), product_reg_in); //load new value from operand
	yt61_reg #(48) product(.reg_d(product_reg_in),.reg_prn({48{1'b1}}),.reg_clrn(~{48{regClear_out}}),.reg_f(product_reg_out),.write_enable(1'b1),.clk(clock)); //data_inputRDY_in is on 1 clock cycle after counter reaches 32 and stays there till mult or div are asserted.
	wire[31:0] product_reg_lsb;
	wire[15:0] product_reg_msb;
	assign product_reg_msb = product_reg_out[47:32];
	assign product_reg_lsb = product_reg_out[31:0];

	//ALU for mult
	wire[47:0] shifter_in_mult;
	wire[15:0] mult_ALU_out,msb_to_shifter;
	wire lastcin_wire;

	Adder16 my_adder16(product_reg_msb,mtplicnd_dvsor_reg_out,mult_ALU_out,reg_carry_wire_out,reg_carry_wire_in,lastcin_wire);
	wire alu_main_overflow = reg_carry_wire_in ^ lastcin_wire;

	//shifter for mult
	my_tri #(16) tri_3(mult_ALU_out, product_reg_out[0], msb_to_shifter);
	my_tri #(16) tri_4(product_reg_msb, ~product_reg_out[0], msb_to_shifter);
	assign shifter_in_mult = {msb_to_shifter,product_reg_lsb};
	assign shifter_out_mult = shifter_in_mult >>> 1;

	//choose between mult or div reg
	wire[47:0] chooseRegOut,remainder_reg_out_onlyQuotient;
	wire[31:0] chooseRegOutTrunc;
	assign remainder_reg_out_onlyQuotient = {{16{1'b0}},remainder_reg_out[31:0]}; // cut away the remainder (16 msb)
	my_tri #(48) multordiv1(product_reg_out,mult_sr_out,chooseRegOut);
	my_tri #(48) multordiv2(remainder_reg_out_onlyQuotient,div_sr_out,chooseRegOut);
	assign chooseRegOutTrunc = chooseRegOut[31:0];

	// subtractor for possible negation of final output based on signs of inputs
	wire[31:0] reg_out_minus_one,result;
	wire uselessisNotEqual, uselessisLessThan;
	yt61_alu subtractor(chooseRegOutTrunc, 32'b1, 5'b00001, 5'b00001, reg_out_minus_one, uselessisNotEqual, uselessisLessThan);
	wire[31:0] chooseRegOutTrunc_inverted =	~reg_out_minus_one;
	wire result_sign_tri_ctrl = signA_dff_out ^ signB_dff_out; // same sign is always positive and this wire will be 0. different sign is always negative and this wire will be 1.
	my_tri invertOutput1(chooseRegOutTrunc_inverted, result_sign_tri_ctrl, result);
	my_tri invertOutput2(chooseRegOutTrunc, ~result_sign_tri_ctrl, result);
	assign data_result = result;
	assign data_exception = ((alu_main_overflow | (result_sign_tri_ctrl ^ result[31]) | ~(|mtplicnd_dvsor_reg_out) ) & data_resultRDY_in);
endmodule

// FROM MY REGFILE.v: tristate buffer, decoder, dff, 32 bit register
// tristate buffer to control read / write
module my_tri(in, enable, out);
	parameter DATA_WIDTH = 32;
	input [DATA_WIDTH-1:0]in;
	input enable;
	output [DATA_WIDTH-1:0]out;
	assign out = enable ? in : {DATA_WIDTH{1'bz}};
endmodule

// 5:32 one-hot decoder (using lecture 3 code)
module my_decoder(decoder_select,decoder_out,decoder_enable);
	input [4:0]decoder_select;
	input decoder_enable;
	output [31:0]decoder_out;
	assign decoder_out = (decoder_enable << decoder_select);
endmodule

//32 bit register
module yt61_reg(reg_d,reg_prn,reg_clrn,reg_f,write_enable,clk);
	parameter DATA_WIDTH = 32;
	input [DATA_WIDTH-1:0] reg_d, reg_clrn, reg_prn;
	input write_enable,clk;
	output [DATA_WIDTH-1:0]reg_f;
	genvar c;
	generate
		for (c = 0; c<=(DATA_WIDTH-1); c = c + 1) begin: loopDFFs
			DFFE my_dff(.d(reg_d[c]),.clrn(reg_clrn[c]),.prn(reg_prn[c]),.clk(clk),.q(reg_f[c]),.ena(write_enable));
		end
	endgenerate
endmodule

module up_counter(out, enable, clk, reset);
	output [7:0] out;
	input enable, clk, reset;
	reg [7:0] out;
	always @(posedge clk)
		if (reset) begin
			out = 8'b0 ;
		end else if (enable) begin
			out <= out + 8'b1;
		end
endmodule

// FROM ALU.v
module yt61_alu(data_operandA, data_operandB, ctrl_ALUopcode, ctrl_shiftamt, data_result, isNotEqual, isLessThan);
	input [31:0] data_operandA, data_operandB;
	input [4:0] ctrl_ALUopcode, ctrl_shiftamt;
	output [31:0] data_result;
	output isNotEqual, isLessThan;

	wire [31:0] mult_ALU_out,sll_out,sra_out;
	wire [31:0] or_out = data_operandA | data_operandB;
	wire [31:0] and_out = data_operandA & data_operandB;
	wire carryout,lastcarryin; //for overflow detection
	wire overflow = carryout ^ lastcarryin;
	assign isLessThan = data_result[31] ^ overflow;
	assign isNotEqual = |data_result;

	sll_barrel_shifter sll_b_s(ctrl_shiftamt,data_operandA,sll_out);
	sra_barrel_shifter sra_b_s(ctrl_shiftamt,data_operandA,sra_out);

	// ************* control goes here *************
	wire ctrl_subtract = ~ctrl_ALUopcode[4] & ~ctrl_ALUopcode[3] & ~ctrl_ALUopcode[2] & ~ctrl_ALUopcode[1] & ctrl_ALUopcode[0];
	wire ctrl_and = ~ctrl_ALUopcode[4] & ~ctrl_ALUopcode[3] & ~ctrl_ALUopcode[2] & ctrl_ALUopcode[1] & ~ctrl_ALUopcode[0];
	wire ctrl_or = ~ctrl_ALUopcode[4] & ~ctrl_ALUopcode[3] & ~ctrl_ALUopcode[2] & ctrl_ALUopcode[1] & ctrl_ALUopcode[0];
	wire ctrl_alu = ~ctrl_ALUopcode[4] & ~ctrl_ALUopcode[3] & ~ctrl_ALUopcode[2] & ~ctrl_ALUopcode[1];
	wire ctrl_sll =	~ctrl_ALUopcode[4] & ~ctrl_ALUopcode[3] & ctrl_ALUopcode[2] & ~ctrl_ALUopcode[1] & ~ctrl_ALUopcode[0];
	wire ctrl_sra = ~ctrl_ALUopcode[4] & ~ctrl_ALUopcode[3] & ctrl_ALUopcode[2] & ~ctrl_ALUopcode[1] & ctrl_ALUopcode[0];
	wire ctrl_xor = ~ctrl_ALUopcode[4] & ctrl_ALUopcode[3] & ~ctrl_ALUopcode[2] & ~ctrl_ALUopcode[1] & ~ctrl_ALUopcode[0];


	Adder32 my_adder32(data_operandA,data_operandB,mult_ALU_out,ctrl_subtract,carryout,lastcarryin);

	my_tri or_tri(or_out,ctrl_or,data_result);
	my_tri and_tri(and_out,ctrl_and,data_result);
	my_tri alu_tri(mult_ALU_out,ctrl_alu,data_result);
	my_tri sll_tri(sll_out,ctrl_sll,data_result);
	my_tri sra_tri(sra_out,ctrl_sra,data_result);
endmodule

module sll_barrel_shifter(shamt, operand, out);
	input[4:0] shamt;
	input[31:0] operand;
	output[31:0] out;
	wire[31:0] w16_8, w8_4, w4_2, w2_1;
	my_tri tri_thru_16(operand<<16, shamt[4], w16_8);
	my_tri tri_no_16(operand, ~shamt[4], w16_8);
	my_tri tri_thru_8(w16_8<<8, shamt[3],w8_4);
	my_tri tri_no_8(w16_8,~shamt[3],w8_4);
	my_tri tri_thru_4(w8_4<<4,shamt[2],w4_2);
	my_tri tri_no_4(w8_4,~shamt[2],w4_2);
	my_tri tri_thru_2(w4_2<<2,shamt[1],w2_1);
	my_tri tri_no_2(w4_2,~shamt[1],w2_1);
	my_tri tri_thru_1(w2_1<<1,shamt[0],out);
	my_tri tri_no_1(w2_1,~shamt[0],out);
endmodule

module sra_barrel_shifter(shamt, operand, out);
	input[4:0] shamt;
	input[31:0] operand;
	output[31:0] out;
	wire[31:0] msb,mask2,intermediate;
	wire[30:0] mask;
	assign msb = {32{operand[31]}};
	wire[31:0] w16_8, w8_4, w4_2, w2_1;
	my_tri tri_thru_16(operand>>16, shamt[4], w16_8);
	my_tri tri_no_16(operand, ~shamt[4], w16_8);
	my_tri tri_thru_8(w16_8>>8, shamt[3],w8_4);
	my_tri tri_no_8(w16_8,~shamt[3],w8_4);
	my_tri tri_thru_4(w8_4>>4,shamt[2],w4_2);
	my_tri tri_no_4(w8_4,~shamt[2],w4_2);
	my_tri tri_thru_2(w4_2>>2,shamt[1],w2_1);
	my_tri tri_no_2(w4_2,~shamt[1],w2_1);
	my_tri tri_thru_1(w2_1>>1,shamt[0],intermediate);
	my_tri tri_no_1(w2_1,~shamt[0],intermediate);
	inverse_thermometer_decoder my_t_d(shamt, mask);
	assign mask2 = {mask,1'b0} & msb;
	assign out = intermediate | mask2;
endmodule

module inverse_thermometer_decoder(binary, thermometer);
	input	[4:0]	 binary;
	output [30:0] thermometer;
	generate
	genvar i;
		for(i=0; i<=30; i=i+1) begin : thermometerLoop
			 assign thermometer[30-i] = (binary > i) ? 1'b1 : 1'b0;
		end
	endgenerate
endmodule

// code adapted from Dally and Harting pg 258
// 8 bit hierarchical carry-lookahead module (log(N) gate delay)
module Cla8(a, b, ci, co);
	input[7:0] a, b;
	input ci;
	output[8:0] co;
	wire [7:0] p, g, p2, g2, p4, g4, p8, g8;

	//input stage of PG cells
	assign p = a ^ b;
	assign g = a & b;

	//p and g across multiple bits
	assign p2 = p & {1'b0, p[7:1]};
	assign g2 = {1'b0, g[7:1]} | (g & {1'b0, p[7:1]});
	assign p4 = p2 & {2'b00, p2[7:2]};
	assign g4 = {2'b00, g2[7:2]} | (g2 & {2'b00, p2[7:2]});
	assign p8 = p4 & {4'b0000, p4[7:4]};
	assign g8 = {4'b0000, g4[7:4]} | (g4 & {4'b0000, p4[7:4]});
	assign co[0] = ci;
	assign co[8] = g8[0] | (ci & p8[0]);
	assign co[4] = g4[0] | (ci & p4[0]);
	assign co[2] = g2[0] | (ci & p2[0]);
	assign co[1] = g[0] | (ci & p[0]);
	assign co[6] =	 g2[4] | (co[4] & p2[4]);
	assign co[5] = g[4] | (co[4] & p[4]);
	assign co[3] = g[2] | (co[2] & p[2]);
	assign co[7] = g[6] | (co[6] & p[6]);
endmodule

//8 bit adder with carry lookahead
module Adder2(aa,bb,ccin,ccout,ss,lastcarryin);
	parameter n = 8;
	input [n-1:0] aa, bb;
	input ccin;
	output [n-1:0] ss;
	output ccout;
	output lastcarryin;

	wire[n:0] cla_carries;
	wire[n-1:0] p	= aa ^ bb;
	//wire[n-1:0] g = aa & bb;
	Cla8 my_Cla8(aa[n-1:0], bb[n-1:0], ccin, cla_carries[n:0]);
	assign ss = p ^ cla_carries[n-1:0];
	assign lastcarryin = cla_carries[n-1];
	assign ccout = cla_carries[n];
endmodule

// connect 4 8 bit adders to do ripple carry between 8 bit blocks but carry lookahead within 8 bit blocks.
module Adder32(aaa,bbb,sss,subtract,cccout,lastCarryin4);
	input subtract;
	input[31:0] aaa,bbb;
	output [31:0] sss;
	output cccout, lastCarryin4; //for overflow detection

	wire[31:0] bbbinverse = ~bbb;
	wire[31:0] invOrNot;
	wire lastCarryin1,lastCarryin2,lastCarryin3; //ignore these
	my_tri mytri1(bbb,~subtract,invOrNot);
	my_tri mytri2(bbbinverse,subtract,invOrNot);

	wire cccout1, cccout2, cccout3;
	wire[7:0] sss1,sss2,sss3,sss4;
	Adder2 my_adder21(aaa[7:0],invOrNot[7:0],subtract,cccout1,sss1[7:0],lastCarryin1);
	Adder2 my_adder22(aaa[15:8],invOrNot[15:8],cccout1,cccout2,sss2[7:0],lastCarryin2);
	Adder2 my_adder23(aaa[23:16],invOrNot[23:16],cccout2,cccout3,sss3[7:0],lastCarryin3);
	Adder2 my_adder24(aaa[31:24],invOrNot[31:24],cccout3,cccout,sss4[7:0],lastCarryin4);
	assign sss = {sss4[7:0],sss3[7:0],sss2[7:0],sss1[7:0]};
endmodule

module Adder16(aaa,bbb,sss,cccin,cccout,lastCarryin2); //16 bit adder for mult/div
	input cccin;
	input[15:0] aaa,bbb;
	output [15:0] sss;
	output cccout, lastCarryin2; //for overflow detection
	wire lastCarryin1; //ignore this
	wire cccout1;
	wire[7:0] sss1,sss2;
	Adder2 my_adder21(aaa[7:0],bbb[7:0],cccin,cccout1,sss1[7:0],lastCarryin1);
	Adder2 my_adder22(aaa[15:8],bbb[15:8],cccout1,cccout,sss2[7:0],lastCarryin2);
	assign sss = {sss2[7:0],sss1[7:0]};
endmodule

// module regfile(clock, ctrl_writeEnable, ctrl_reset, ctrl_writeReg, ctrl_readRegA, ctrl_readRegB, data_writeReg, data_readRegA, data_readRegB);
// 	input clock, ctrl_writeEnable, ctrl_reset;
// 	input [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
// 	input [31:0] data_writeReg;
// 	output [31:0] data_readRegA, data_readRegB;
//
// 	wire [31:0]read_decoderA_wire_out, read_decoderB_wire_out, write_decoder_wire_out;
// 	wire [31:0]reg_to_tristate_wire [31:0]; // wire from register to Tristate bufferS for readReg
// 	wire write_to_reg_wire [31:0]; // wire from data_writereg to all registers
//
// 	my_decoder read_decoderA(ctrl_readRegA, read_decoderA_wire_out, 1);
// 	my_decoder read_decoderB(ctrl_readRegB, read_decoderB_wire_out, 1);
// 	my_decoder write_decoder(ctrl_writeReg, write_decoder_wire_out, ctrl_writeEnable); // decoder disabled if write enable for REGISTER FILE is off
//
// 	genvar a;
// 	generate
// 		for (a = 0; a <= 31; a = a + 1) begin: loopTriStateBuffersA
// 			yt61_reg thisRegister(.reg_d(data_writeReg), .reg_prn({32{1'b1}}), .reg_clrn({32{~ctrl_reset}}), .clk(clock), .reg_f(reg_to_tristate_wire[a]), .write_enable(write_decoder_wire_out[a])); // create registers and link to two sets of tristate buffers which are controlled by two decoders.reg_d,reg_prn,reg_clrn,reg_f,write_enable,clk
// 			my_tri thisTriA(.in(reg_to_tristate_wire[a]), .enable(read_decoderA_wire_out[a]), .out(data_readRegA));
// 			my_tri thisTriB(.in(reg_to_tristate_wire[a]), .enable(read_decoderB_wire_out[a]), .out(data_readRegB));
// 		end
// 	endgenerate
// endmodule

module regfile(clock, ctrl_writeEnable, ctrl_reset, ctrl_writeReg, ctrl_readRegA, ctrl_readRegB, data_writeReg, data_readRegA, data_readRegB, data_out0, data_out1, data_out2, data_out3, data_out4, data_out5, data_out6, data_out7, data_out31);
	input clock, ctrl_writeEnable, ctrl_reset;
	input [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
	input [31:0] data_writeReg;
	output [31:0] data_readRegA, data_readRegB;
	output[31:0] data_out0, data_out1, data_out2, data_out3, data_out4, data_out5, data_out6, data_out7, data_out31;

	wire [31:0]read_decoderA_wire_out, read_decoderB_wire_out, write_decoder_wire_out;
	wire [31:0]reg_to_tristate_wire [31:0]; // wire from register to Tristate bufferS for readReg
	wire write_to_reg_wire [31:0]; // wire from data_writereg to all registers

	my_decoder read_decoderA(ctrl_readRegA, read_decoderA_wire_out, 1);
	my_decoder read_decoderB(ctrl_readRegB, read_decoderB_wire_out, 1);
	my_decoder write_decoder(ctrl_writeReg, write_decoder_wire_out, ctrl_writeEnable); // decoder disabled if write enable for REGISTER FILE is off

	genvar a;
	generate
		for (a = 1; a <= 31; a = a + 1) begin: loopTriStateBuffersA
			yt61_reg thisRegister(.reg_d(data_writeReg), .reg_prn({32{1'b1}}), .reg_clrn({32{~ctrl_reset}}), .clk(clock), .reg_f(reg_to_tristate_wire[a]), .write_enable(write_decoder_wire_out[a])); // create registers and link to two sets of tristate buffers which are controlled by two decoders.reg_d,reg_prn,reg_clrn,reg_f,write_enable,clk

			my_tri thisTriA(.in(reg_to_tristate_wire[a]), .enable(read_decoderA_wire_out[a]), .out(data_readRegA));
			my_tri thisTriB(.in(reg_to_tristate_wire[a]), .enable(read_decoderB_wire_out[a]), .out(data_readRegB));
		end
	endgenerate
	my_tri thisTriA(.in(32'b0), .enable(read_decoderA_wire_out[0]), .out(data_readRegA));
	my_tri thisTriB(.in(32'b0), .enable(read_decoderB_wire_out[0]), .out(data_readRegB));

	assign data_out1 = reg_to_tristate_wire[1];
	assign data_out2 = reg_to_tristate_wire[2];
	assign data_out3 = reg_to_tristate_wire[3];
	assign data_out4 = reg_to_tristate_wire[4];
	assign data_out5 = reg_to_tristate_wire[5];
	assign data_out6 = reg_to_tristate_wire[6];
	assign data_out7 = reg_to_tristate_wire[7];
	assign data_out31 = reg_to_tristate_wire[31];

endmodule

module branchPredictor(clock, ctrl_writeEnable, ctrl_reset, ctrl_writeReg, ctrl_readRegA, data_writeReg, data_readRegA);
//, data_out0, data_out1, data_out2, data_out3, data_out4, data_out5);
	input clock, ctrl_writeEnable, ctrl_reset;
	input [4:0] ctrl_writeReg, ctrl_readRegA;
	input [31:0] data_writeReg;
	output [31:0] data_readRegA;
	// output[31:0] data_out0, data_out1, data_out2, data_out3, data_out4, data_out5;

	wire [31:0]read_decoderA_wire_out, write_decoder_wire_out;
	wire [31:0]reg_to_tristate_wire [31:0]; // wire from register to Tristate bufferS for readReg
	wire write_to_reg_wire [31:0]; // wire from data_writereg to all registers

	my_decoder read_decoderA(ctrl_readRegA, read_decoderA_wire_out, 1);
	my_decoder write_decoder(ctrl_writeReg, write_decoder_wire_out, ctrl_writeEnable); // decoder disabled if write enable for REGISTER FILE is off

	genvar a;
	generate
		for (a = 0; a <= 31; a = a + 1) begin: loopTriStateBuffersA
			yt61_reg thisRegister(.reg_d(data_writeReg), .reg_prn({32{1'b1}}), .reg_clrn({32{~ctrl_reset}}), .clk(clock), .reg_f(reg_to_tristate_wire[a]), .write_enable(write_decoder_wire_out[a])); // create registers and link to two sets of tristate buffers which are controlled by two decoders.reg_d,reg_prn,reg_clrn,reg_f,write_enable,clk
			my_tri thisTriA(.in(reg_to_tristate_wire[a]), .enable(read_decoderA_wire_out[a]), .out(data_readRegA));
		end
	endgenerate

	// assign data_out0 = reg_to_tristate_wire[0];
	// assign data_out1 = reg_to_tristate_wire[1];
	// assign data_out2 = reg_to_tristate_wire[2];
	// assign data_out3 = reg_to_tristate_wire[3];
	// assign data_out4 = reg_to_tristate_wire[4];
	// assign data_out5 = reg_to_tristate_wire[5];

endmodule

module reservationUnit(clock, ctrl_writeEnable, ctrl_reset, ctrl_readA, ctrl_writeA, readA, writeA);
	input clock, ctrl_writeEnable, ctrl_reset, writeA;
	input [4:0] ctrl_readA, ctrl_writeA;
	output readA;

	wire [31:0] read_decoderA_wire_out, write_decoderA_wire_out;
	wire dff_to_tristate_wire [31:0]; // wire from register to Tristate bufferS for readReg
	wire write_to_dff_wire [31:0];

	my_decoder read_decoderA(ctrl_readA, read_decoderA_wire_out, 1);
	my_decoder write_decoderA(ctrl_writeA, write_decoderA_wire_out, ctrl_writeEnable);

	genvar a;
	generate
		for (a = 0; a <= 31; a = a + 1) begin: loopTriStateBuffersA

			DFFE my_dff(.d(write_to_dff_wire[a]),.clrn(~ctrl_reset),.prn(1'b1),.clk(clk),.q(dff_to_tristate_wire[a]),.ena(write_decoderA_wire_out[a]));
			my_tri thisTriA(.in(dff_to_tristate_wire[a]), .enable(read_decoderA_wire_out[a]), .out(readA));
			my_tri thisTriAw(.in(writeA), .enable(write_decoderA_wire_out[a]), .out(write_to_dff_wire[a]));

		end
	endgenerate
endmodule

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
