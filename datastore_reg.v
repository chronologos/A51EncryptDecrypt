module datastore_reg(ps2data_in, index, datastore_out, write_enable, clk, reset);
  input [7:0] ps2data_in;
  input [4:0] index;
	input write_enable, clk, reset;
  output [223:0] datastore_out;

  wire [31:0] ps2dataCtrl;
  wire [223:0] ps2data224, ps2Ctrl224;

  my_decoder ps2datablock(.decoder_select(index), .decoder_out(ps2dataCtrl), .decoder_enable(1'b1));

  assign ps2data224 = {28{ps2data_in}};


  assign ps2Ctrl224 = {		{8{ps2dataCtrl[27]}}, {8{ps2dataCtrl[26]}}, {8{ps2dataCtrl[25]}}, {8{ps2dataCtrl[24]}}, {8{ps2dataCtrl[23]}},
  {8{ps2dataCtrl[22]}}, {8{ps2dataCtrl[21]}}, {8{ps2dataCtrl[20]}}, {8{ps2dataCtrl[19]}}, {8{ps2dataCtrl[18]}},
  {8{ps2dataCtrl[17]}}, {8{ps2dataCtrl[16]}}, {8{ps2dataCtrl[15]}}, {8{ps2dataCtrl[14]}}, {8{ps2dataCtrl[13]}},
  {8{ps2dataCtrl[12]}}, {8{ps2dataCtrl[11]}}, {8{ps2dataCtrl[10]}}, {8{ps2dataCtrl[9]}}, {8{ps2dataCtrl[8]}},
  {8{ps2dataCtrl[7]}}, {8{ps2dataCtrl[6]}}, {8{ps2dataCtrl[5]}}, {8{ps2dataCtrl[4]}}, {8{ps2dataCtrl[3]}},
  {8{ps2dataCtrl[2]}}, {8{ps2dataCtrl[1]}}, {8{ps2dataCtrl[0]}}			};

  genvar c;
  generate
    for (c = 0; c < 224; c = c + 1) begin: loopDFFs
      DFFE my_dff(.d(ps2data224[c]),.clrn(~reset),.prn(1'b1),.clk(clk),.q(datastore_out[c]),.ena(write_enable && ps2Ctrl224[c]));
    end
  endgenerate
endmodule


// 5:32 one-hot decoder (using lecture 3 code)
module my_decoder(decoder_select,decoder_out,decoder_enable);
	input [4:0]decoder_select;
	input decoder_enable;
	output [31:0]decoder_out;
	assign decoder_out = (decoder_enable << decoder_select);
endmodule
