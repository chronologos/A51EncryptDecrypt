module keyframe_reg(ps2data_in, keyindex, keyframe_out, write_enable, clk, reset);
  input [7:0] ps2data_in;
  input [2:0] keyindex;
	input write_enable, clk, reset;
  output [85:0] keyframe_out;

  wire [7:0] ps2keyCtrl;
  wire [63:0] ps2key64, ps2Ctrl64;

  assign ps2keyCtrl = 1 << keyindex;

  assign ps2key64 = {8{ps2data_in}};

  assign ps2Ctrl64 = {		{8{ps2keyCtrl[7]}}, {8{ps2keyCtrl[6]}}, {8{ps2keyCtrl[5]}}, {8{ps2keyCtrl[4]}},
                      {8{ps2keyCtrl[3]}}, {8{ps2keyCtrl[2]}}, {8{ps2keyCtrl[1]}}, {8{ps2keyCtrl[0]}}			};

  assign keyframe_out[21:0] = 22'h000134; //hard-coded frame

  genvar c;
  generate
    for (c = 0; c < 64; c = c + 1) begin: loopDFFs
      DFFE my_dff(.d(ps2key64[c]),.clrn(~reset),.prn(1'b1),.clk(clk),.q(keyframe_out[c+22]),.ena(write_enable && ps2Ctrl64[c]));
    end
  endgenerate

endmodule
