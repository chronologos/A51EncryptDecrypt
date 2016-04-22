module datastore_reg(ps2data_in, index, datastore_out, write_enable, clk, reset);
  input [3:0] ps2data_in; //scantohex
  input [4:0] index;
	input write_enable, clk, reset;
  output [127:0] datastore_out;

  wire [31:0] ps2dataCtrl;
  wire [127:0] ps2data128, ps2Ctrl128;

  my_decoder ps2datablock(.decoder_select(index), .decoder_out(ps2dataCtrl), .decoder_enable(1'b1));

  assign ps2data128 = {32{ps2data_in}};


  assign ps2Ctrl128 = {		{4{ps2dataCtrl[31]}},{4{ps2dataCtrl[30]}},{4{ps2dataCtrl[29]}},{4{ps2dataCtrl[28]}},{4{ps2dataCtrl[27]}}, {4{ps2dataCtrl[26]}}, {4{ps2dataCtrl[25]}}, {4{ps2dataCtrl[24]}}, {4{ps2dataCtrl[23]}},
  {4{ps2dataCtrl[22]}}, {4{ps2dataCtrl[21]}}, {4{ps2dataCtrl[20]}}, {4{ps2dataCtrl[19]}}, {4{ps2dataCtrl[18]}},
  {4{ps2dataCtrl[17]}}, {4{ps2dataCtrl[16]}}, {4{ps2dataCtrl[15]}}, {4{ps2dataCtrl[14]}}, {4{ps2dataCtrl[13]}},
  {4{ps2dataCtrl[12]}}, {4{ps2dataCtrl[11]}}, {4{ps2dataCtrl[10]}}, {4{ps2dataCtrl[9]}}, {4{ps2dataCtrl[8]}},
  {4{ps2dataCtrl[7]}}, {4{ps2dataCtrl[6]}}, {4{ps2dataCtrl[5]}}, {4{ps2dataCtrl[4]}}, {4{ps2dataCtrl[3]}},
  {4{ps2dataCtrl[2]}}, {4{ps2dataCtrl[1]}}, {4{ps2dataCtrl[0]}}			};

  genvar c;
  generate
    for (c = 0; c < 128; c = c + 1) begin: loopDFFs
      DFFE my_dff(.d(ps2data128[c]),.clrn(~reset),.prn(1'b1),.clk(clk),.q(datastore_out[c]),.ena(write_enable && ps2Ctrl128[c]));
    end
  endgenerate
endmodule
